<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Api\Concerns\RespondsWithJson;
use App\Http\Controllers\Controller;
use App\Http\Resources\Api\InterventionResource;
use App\Models\Client;
use App\Models\Intervention;
use App\Models\Product;
use App\Models\Wallet;
use App\Models\WalletTransaction;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;

class InterventionApiController extends Controller
{
    use RespondsWithJson;

    private const TYPES = ['Manutenção', 'Atualizações', 'Desenvolvimento', 'Suporte', 'Outro'];

    public function index(Request $request): JsonResponse
    {
        $clients = Client::with('wallet:id,client_id,balance_seconds')
            ->orderBy('name')
            ->get()
            ->map(fn ($client) => [
                'id' => $client->id,
                'name' => $client->name,
                'company' => $client->company,
                'has_active_pack' => ($client->wallet?->balance_seconds ?? 0) > 0,
                'hourly_rate' => $client->hourly_rate,
            ]);

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
            ->map(fn ($pack) => [
                'id' => $pack->id,
                'name' => $pack->name,
                'pack_items' => $pack->packItems->sortBy('order')->values()->map(fn ($item) => [
                    'id' => $item->id,
                    'hours' => $item->hours,
                    'normal_price' => $item->normal_price,
                    'pack_price' => $item->pack_price,
                    'validity_months' => $item->validity_months,
                    'featured' => (bool) $item->featured,
                ])->toArray(),
            ]);

        $wallet = null;
        $transactions = [];
        $selectedClient = null;

        if ($selectedClientId) {
            $selectedClient = Client::find($selectedClientId);
            $wallet = Wallet::firstOrCreate(['client_id' => $selectedClientId], ['balance_seconds' => 0, 'balance_amount' => 0]);
            $transactions = WalletTransaction::with(['product:id,name', 'packItem:id,product_id,hours,pack_price,validity_months', 'intervention:id,type'])
                ->where('wallet_id', $wallet->id)
                ->orderByDesc('transaction_at')
                ->take(50)
                ->get();
        }

        return $this->success([
            'clients' => $clients,
            'interventions' => InterventionResource::collection($interventions),
            'selected_client_id' => $selectedClientId,
            'selected_tab' => $selectedTab,
            'types' => self::TYPES,
            'selected_client' => $selectedClient,
            'wallet' => $wallet,
            'transactions' => $transactions,
            'packs' => $packs,
        ]);
    }

    public function store(Request $request): JsonResponse
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
            return $this->error('Indica o valor/hora.', ['hourly_rate' => ['Indica o valor/hora.']], 422);
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
            Client::where('id', $data['client_id'])->update(['hourly_rate' => $hourlyRate]);
        }

        return $this->success([
            'intervention' => new InterventionResource($intervention->load('client')),
        ], 'Intervenção iniciada.', 201);
    }

    public function pause(Intervention $intervention): JsonResponse
    {
        if ($intervention->status !== 'running') {
            return $this->error('Só podes pausar intervenções em execução.', [], 422);
        }

        $intervention->update(['status' => 'paused', 'paused_at' => now()]);

        return $this->success(['intervention' => new InterventionResource($intervention->fresh('client'))], 'Intervenção em pausa.');
    }

    public function resume(Intervention $intervention): JsonResponse
    {
        if ($intervention->status !== 'paused' || ! $intervention->paused_at) {
            return $this->error('Só podes retomar intervenções em pausa.', [], 422);
        }

        $pausedSeconds = $intervention->paused_at->diffInSeconds(now());
        $intervention->update([
            'status' => 'running',
            'paused_at' => null,
            'total_paused_seconds' => $intervention->total_paused_seconds + $pausedSeconds,
        ]);

        return $this->success(['intervention' => new InterventionResource($intervention->fresh('client'))], 'Intervenção retomada.');
    }

    public function finish(Request $request, Intervention $intervention): JsonResponse
    {
        $data = $request->validate([
            'finish_notes' => ['nullable', 'string', 'max:2000'],
            'ended_at' => ['nullable', 'date'],
            'duration_minutes' => ['nullable', 'integer', 'min:0'],
        ]);

        if ($intervention->status === 'completed') {
            return $this->error('Intervenção já concluída.', [], 422);
        }

        if (! empty($data['ended_at']) && ! empty($data['duration_minutes'])) {
            return $this->error('Indica apenas a hora de fim ou a duração.', ['ended_at' => ['Indica apenas a hora de fim ou a duração.']], 422);
        }

        $now = now();
        $endAtInput = ! empty($data['ended_at']) ? Carbon::parse($data['ended_at']) : null;
        $durationMinutes = isset($data['duration_minutes']) ? (int) $data['duration_minutes'] : null;

        if ($endAtInput && $intervention->started_at && $endAtInput->lessThan($intervention->started_at)) {
            return $this->error('A hora de fim não pode ser anterior ao início.', ['ended_at' => ['A hora de fim não pode ser anterior ao início.']], 422);
        }

        $totalPaused = $intervention->total_paused_seconds;
        if ($intervention->status === 'paused' && $intervention->paused_at) {
            $pauseEnd = $endAtInput ?? $now;
            if ($pauseEnd->greaterThan($intervention->paused_at)) {
                $totalPaused += $intervention->paused_at->diffInSeconds($pauseEnd);
            }
        }

        if ($durationMinutes !== null) {
            $totalSeconds = max(0, $durationMinutes * 60);
        } else {
            $endAt = $endAtInput ?? $now;
            $totalSeconds = max(0, $intervention->started_at->diffInSeconds($endAt) - $totalPaused);
        }

        if ($durationMinutes !== null && $intervention->started_at) {
            $endAt = $intervention->started_at->copy()->addSeconds($totalPaused + $totalSeconds);
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
            $wallet = Wallet::firstOrCreate(['client_id' => $intervention->client_id], ['balance_seconds' => 0, 'balance_amount' => 0]);

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
                $hourlyRate = (float) ($intervention->hourly_rate ?? $intervention->client?->hourly_rate ?? 0);
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

        return $this->success(['intervention' => new InterventionResource($intervention->fresh('client'))], 'Intervenção concluída.');
    }
}
