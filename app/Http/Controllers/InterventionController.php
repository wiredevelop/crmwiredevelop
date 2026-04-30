<?php

namespace App\Http\Controllers;

use App\Mail\InterventionFinished;
use App\Mail\InterventionStarted;
use App\Models\Client;
use App\Models\Intervention;
use App\Models\Product;
use App\Models\Wallet;
use App\Models\WalletTransaction;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Mail;
use Inertia\Inertia;
use Inertia\Response;

class InterventionController extends Controller
{
    private const TYPES = [
        'Manutenção',
        'Atualizações',
        'Desenvolvimento',
        'Suporte',
        'Outro',
    ];

    public function index(Request $request): Response
    {
        $clients = Client::with('wallet:id,client_id,balance_seconds')
            ->orderBy('name')
            ->get()
            ->map(function ($client) {
                return [
                    'id' => $client->id,
                    'name' => $client->name,
                    'company' => $client->company,
                    'has_active_pack' => ($client->wallet?->balance_seconds ?? 0) > 0,
                    'hourly_rate' => $client->hourly_rate,
                ];
            });
        $selectedClientId = $request->query('client_id');
        $selectedTab = $request->query('tab');
        if (! in_array($selectedTab, ['pack', 'no-pack'], true)) {
            $selectedTab = null;
        }

        if ($selectedClientId && ! $clients->contains('id', (int) $selectedClientId)) {
            $selectedClientId = null;
        }

        $interventions = Intervention::with('client:id,name,company')
            ->when($selectedClientId, fn ($q) => $q->where('client_id', $selectedClientId))
            ->orderByDesc('started_at')
            ->take(50)
            ->get();

        $packs = Product::with('packItems')
            ->where('type', 'pack')
            ->where('active', true)
            ->orderBy('name')
            ->get()
            ->map(function ($pack) {
                return [
                    'id' => $pack->id,
                    'name' => $pack->name,
                    'pack_items' => $pack->packItems
                        ->sortBy('order')
                        ->values()
                        ->map(fn ($item) => [
                            'id' => $item->id,
                            'hours' => $item->hours,
                            'normal_price' => $item->normal_price,
                            'pack_price' => $item->pack_price,
                            'validity_months' => $item->validity_months,
                            'featured' => (bool) $item->featured,
                        ])
                        ->toArray(),
                ];
            });

        $wallet = null;
        $transactions = [];
        $selectedClient = null;

        if ($selectedClientId) {
            $selectedClient = Client::find($selectedClientId);
            $wallet = Wallet::firstOrCreate([
                'client_id' => $selectedClientId,
            ], [
                'balance_seconds' => 0,
                'balance_amount' => 0,
            ]);

            $transactions = WalletTransaction::with([
                'product:id,name',
                'packItem:id,product_id,hours,pack_price,validity_months',
                'intervention:id,type',
            ])
                ->where('wallet_id', $wallet->id)
                ->orderByDesc('transaction_at')
                ->take(50)
                ->get();
        }

        return Inertia::render('Interventions/Index', [
            'clients' => $clients,
            'interventions' => $interventions,
            'selectedClientId' => $selectedClientId,
            'selectedTab' => $selectedTab,
            'types' => self::TYPES,
            'selectedClient' => $selectedClient,
            'wallet' => $wallet,
            'transactions' => $transactions,
            'packs' => $packs,
        ]);
    }

    public function store(Request $request): RedirectResponse
    {
        $data = $request->validate([
            'client_id' => ['required', 'exists:clients,id'],
            'type' => ['required', 'string', 'max:50'],
            'notes' => ['nullable', 'string', 'max:2000'],
            'is_pack' => ['nullable', 'boolean'],
            'hourly_rate' => ['nullable', 'numeric', 'min:0'],
        ]);

        $isPack = $data['is_pack'] ?? true;
        $hourlyRate = $data['hourly_rate'] ?? null;

        if (! $isPack && ($hourlyRate === null || (float) $hourlyRate <= 0)) {
            return back()->withErrors([
                'hourly_rate' => 'Indica o valor/hora.',
            ]);
        }

        $intervention = Intervention::create([
            'client_id' => $data['client_id'],
            'type' => $data['type'],
            'status' => 'running',
            'notes' => $data['notes'] ?? null,
            'is_pack' => $isPack,
            'hourly_rate' => $isPack ? null : $hourlyRate,
            'started_at' => now(),
        ]);

        if (! $isPack && $hourlyRate !== null) {
            Client::where('id', $data['client_id'])
                ->update(['hourly_rate' => $hourlyRate]);
        }

        $this->notifyStart($intervention);

        return back()->with('success', 'Intervenção iniciada.');
    }

    public function pause(Intervention $intervention): RedirectResponse
    {
        if ($intervention->status !== 'running') {
            return back()->with('error', 'Só podes pausar intervenções em execução.');
        }

        $intervention->update([
            'status' => 'paused',
            'paused_at' => now(),
        ]);

        return back()->with('success', 'Intervenção em pausa.');
    }

    public function resume(Intervention $intervention): RedirectResponse
    {
        if ($intervention->status !== 'paused' || ! $intervention->paused_at) {
            return back()->with('error', 'Só podes retomar intervenções em pausa.');
        }

        $pausedSeconds = $intervention->paused_at->diffInSeconds(now());

        $intervention->update([
            'status' => 'running',
            'paused_at' => null,
            'total_paused_seconds' => $intervention->total_paused_seconds + $pausedSeconds,
        ]);

        return back()->with('success', 'Intervenção retomada.');
    }

    public function finish(Intervention $intervention): RedirectResponse
    {
        $data = request()->validate([
            'finish_notes' => ['nullable', 'string', 'max:2000'],
            'ended_at' => ['nullable', 'date'],
            'duration_minutes' => ['nullable', 'integer', 'min:0'],
            'duration_input' => ['nullable', 'regex:/^\d{1,3}:\d{2}:\d{2}$/'],
        ]);

        if ($intervention->status === 'completed') {
            return back()->with('error', 'Intervenção já concluída.');
        }

        if (! empty($data['ended_at']) && (! empty($data['duration_minutes']) || ! empty($data['duration_input']))) {
            return back()->withErrors([
                'ended_at' => 'Indica apenas a hora de fim ou a duração.',
            ]);
        }

        $now = now();
        $endAtInput = ! empty($data['ended_at']) ? Carbon::parse($data['ended_at']) : null;
        $durationMinutes = isset($data['duration_minutes']) ? (int) $data['duration_minutes'] : null;
        $durationSeconds = ! empty($data['duration_input'])
            ? $this->parseDurationInput($data['duration_input'])
            : ($durationMinutes !== null ? max(0, $durationMinutes * 60) : null);

        if ($endAtInput && $intervention->started_at && $endAtInput->lessThan($intervention->started_at)) {
            return back()->withErrors([
                'ended_at' => 'A hora de fim não pode ser anterior ao início.',
            ]);
        }

        $totalPaused = $intervention->total_paused_seconds;
        if ($intervention->status === 'paused' && $intervention->paused_at) {
            $pauseEnd = $endAtInput ?? $now;
            if ($pauseEnd->greaterThan($intervention->paused_at)) {
                $totalPaused += $intervention->paused_at->diffInSeconds($pauseEnd);
            }
        }

        $totalSeconds = 0;
        if ($durationSeconds !== null) {
            $totalSeconds = $durationSeconds;
        } elseif ($intervention->started_at) {
            $endAt = $endAtInput ?? $now;
            $totalSeconds = max(
                0,
                $intervention->started_at->diffInSeconds($endAt) - $totalPaused
            );
        }

        if ($durationSeconds !== null && $intervention->started_at) {
            $endAt = $intervention->started_at
                ->copy()
                ->addSeconds($totalPaused + $totalSeconds);
        } else {
            $endAt = $endAtInput ?? $now;
        }

        $intervention->update([
            'status' => 'completed',
            'paused_at' => null,
            'ended_at' => $endAt,
            'total_paused_seconds' => $totalPaused,
            'total_seconds' => $totalSeconds,
            'finish_notes' => $data['finish_notes'] ?? null,
        ]);

        $seconds = (int) $totalSeconds;
        if ($seconds > 0) {
            $wallet = Wallet::firstOrCreate([
                'client_id' => $intervention->client_id,
            ], [
                'balance_seconds' => 0,
                'balance_amount' => 0,
            ]);

            if ($intervention->is_pack) {
                WalletTransaction::create([
                    'wallet_id' => $wallet->id,
                    'type' => 'usage',
                    'seconds' => -$seconds,
                    'amount' => null,
                    'description' => 'Intervenção: '.$intervention->type,
                    'intervention_id' => $intervention->id,
                    'transaction_at' => $endAt,
                ]);

                $wallet->balance_seconds -= $seconds;
                $wallet->save();
            } else {
                $intervention->loadMissing('client');
                $hourlyRate = (float) (
                    $intervention->hourly_rate
                    ?? $intervention->client?->hourly_rate
                    ?? 0
                );
                $amount = round(($seconds / 3600) * $hourlyRate, 2);

                WalletTransaction::create([
                    'wallet_id' => $wallet->id,
                    'type' => 'purchase',
                    'seconds' => null,
                    'amount' => $amount,
                    'description' => 'Intervenção: '.$intervention->type,
                    'intervention_id' => $intervention->id,
                    'transaction_at' => $endAt,
                ]);
            }
        }

        $this->notifyFinish($intervention, $totalSeconds);

        return back()->with('success', 'Intervenção concluída.');
    }

    private function notifyStart(Intervention $intervention): void
    {
        $intervention->loadMissing('client');
        $email = $intervention->client?->email;

        if (! $email) {
            return;
        }

        try {
            Mail::to($email)->send(new InterventionStarted($intervention));
        } catch (\Throwable $e) {
            Log::warning('Intervention start email failed: '.$e->getMessage());
        }
    }

    private function notifyFinish(Intervention $intervention, int $totalSeconds): void
    {
        $intervention->loadMissing('client');
        $email = $intervention->client?->email;

        if (! $email) {
            return;
        }

        try {
            Mail::to($email)->send(new InterventionFinished($intervention, $totalSeconds));
        } catch (\Throwable $e) {
            Log::warning('Intervention finish email failed: '.$e->getMessage());
        }
    }

    private function parseDurationInput(string $value): int
    {
        [$hours, $minutes, $seconds] = array_map('intval', explode(':', $value));

        return max(0, ($hours * 3600) + ($minutes * 60) + $seconds);
    }
}
