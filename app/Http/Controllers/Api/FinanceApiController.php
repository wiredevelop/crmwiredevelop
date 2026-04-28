<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Api\Concerns\RespondsWithJson;
use App\Http\Controllers\Controller;
use App\Models\Installment;
use App\Models\Invoice;
use App\Models\Project;
use App\Models\Quote;
use App\Models\TerminalPayment;
use App\Models\WalletTransaction;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Arr;

class FinanceApiController extends Controller
{
    use RespondsWithJson;

    public function index(): JsonResponse
    {
        $projectSales = Project::with(['client:id,name', 'quote:id,project_id,price_development,price_domain_first_year,price_hosting_first_year,price_maintenance_monthly,include_domain,include_hosting', 'invoice:id,project_id,total,status,issued_at,created_at'])
            ->where('status', 'concluido')
            ->orderByDesc('updated_at')
            ->take(200)
            ->get()
            ->map(function ($project) {
                $invoice = $project->invoice;
                $date = $invoice?->issued_at ?? $project->updated_at;
                $amount = $invoice?->total ?? $this->calculateQuoteTotal($project->quote);

                return [
                    'id' => $project->id,
                    'source' => 'project',
                    'type' => 'Projeto',
                    'client_id' => $project->client_id,
                    'client' => $project->client?->name ?? '—',
                    'description' => $project->name ?? '—',
                    'amount' => (float) $amount,
                    'date' => $date?->toDateString(),
                    'status' => $invoice?->status ?? 'pendente',
                    'invoiced' => (bool) $invoice,
                    'to_invoice' => (bool) $invoice,
                    'invoice_id' => $invoice?->id,
                    'invoice_status' => $invoice?->status,
                    'sort_at' => $date?->timestamp ?? 0,
                ];
            })
            ->toBase();

        $productSales = WalletTransaction::with(['wallet.client:id,name', 'product:id,name,type', 'packItem:id,hours', 'intervention:id,type,notes,finish_notes,total_seconds,hourly_rate,is_pack', 'invoice:id,number,status'])
            ->where(function ($query) {
                $query->where('type', 'purchase')
                    ->orWhere(function ($subQuery) {
                        $subQuery->where('type', 'usage')->whereNotNull('intervention_id');
                    });
            })
            ->orderByDesc('transaction_at')
            ->take(200)
            ->get()
            ->map(function ($transaction) {
                $description = $transaction->description ?? $transaction->product?->name ?? '—';
                if ($transaction->packItem?->hours) {
                    $description .= ' • '.$transaction->packItem->hours.'h';
                }

                return [
                    'id' => $transaction->id,
                    'transaction_id' => $transaction->id,
                    'source' => 'transaction',
                    'type' => $transaction->intervention_id ? 'Intervenção' : ($transaction->product?->type === 'pack' ? 'Pack' : 'Produto'),
                    'client_id' => $transaction->wallet?->client_id,
                    'client' => $transaction->wallet?->client?->name ?? '—',
                    'description' => $description,
                    'amount' => (float) ($transaction->amount ?? 0),
                    'date' => $transaction->transaction_at?->toDateString(),
                    'status' => $transaction->type,
                    'is_installment' => (bool) $transaction->is_installment,
                    'installment_count' => $transaction->installment_count,
                    'to_invoice' => (bool) $transaction->to_invoice,
                    'invoice_id' => $transaction->invoice_id,
                    'document_number' => $transaction->invoice?->number,
                    'invoice_status' => $transaction->invoice?->status,
                    'payment_reference' => $transaction->payment_reference,
                    'billing' => $transaction->payment_provider === 'stripe'
                        ? [
                            'provider' => 'stripe',
                            'wants_invoice' => (bool) data_get($transaction->payment_metadata, 'wants_invoice'),
                            'status' => data_get($transaction->payment_metadata, 'status'),
                            'name' => data_get($transaction->payment_metadata, 'billing.billing_name'),
                            'email' => data_get($transaction->payment_metadata, 'billing.billing_email'),
                            'phone' => data_get($transaction->payment_metadata, 'billing.billing_phone'),
                            'vat' => data_get($transaction->payment_metadata, 'billing.billing_vat'),
                            'address' => data_get($transaction->payment_metadata, 'billing.billing_address'),
                            'postal_code' => data_get($transaction->payment_metadata, 'billing.billing_postal_code'),
                            'city' => data_get($transaction->payment_metadata, 'billing.billing_city'),
                            'country' => data_get($transaction->payment_metadata, 'billing.billing_country'),
                        ]
                        : null,
                    'intervention' => $transaction->intervention ? [
                        'notes' => $transaction->intervention->notes,
                        'finish_notes' => $transaction->intervention->finish_notes,
                        'total_seconds' => $transaction->intervention->total_seconds,
                        'hourly_rate' => $transaction->intervention->hourly_rate,
                        'is_pack' => (bool) $transaction->intervention->is_pack,
                    ] : null,
                    'sort_at' => $transaction->transaction_at?->timestamp ?? 0,
                ];
            })
            ->toBase();

        $terminalSales = TerminalPayment::query()
            ->with('user:id,name')
            ->orderByDesc('updated_at')
            ->take(200)
            ->get()
            ->map(fn ($payment) => [
                'id' => $payment->id,
                'source' => 'terminal',
                'type' => 'Terminal',
                'client_id' => null,
                'client' => 'Pagamento presencial',
                'description' => $payment->description ?: 'Tap to Pay',
                'amount' => (float) $payment->gross_amount,
                'date' => $payment->paid_at?->toDateString() ?? $payment->created_at?->toDateString(),
                'status' => $payment->status,
                'invoiced' => false,
                'to_invoice' => false,
                'invoice_id' => null,
                'invoice_status' => null,
                'transaction_id' => $payment->id,
                'payment_reference' => $payment->payment_intent_id,
                'billing' => [
                    'provider' => 'stripe_terminal',
                    'status' => $payment->status,
                    'operator' => $payment->user?->name ?? '—',
                    'card_brand' => $payment->card_brand,
                    'card_last4' => $payment->card_last4,
                    'fee_amount' => (float) $payment->fee_amount,
                    'net_amount' => (float) $payment->net_amount,
                    'charge_id' => $payment->charge_id,
                ],
                'sort_at' => ($payment->paid_at ?? $payment->created_at)?->timestamp ?? 0,
            ])
            ->toBase();

        $sales = $projectSales->merge($productSales)->merge($terminalSales)->sortByDesc('sort_at')->values()->map(fn ($item) => Arr::except($item, ['sort_at']))->toArray();
        $projects = Project::with('client:id,name')->where('status', '!=', 'cancelado')->orderBy('name')->get(['id', 'client_id', 'name', 'status'])->map(fn ($project) => [
            'id' => $project->id,
            'name' => $project->name,
            'status' => $project->status,
            'client_id' => $project->client_id,
            'client' => $project->client?->name ?? '—',
        ])->toArray();
        $installments = Installment::with(['project:id,name', 'client:id,name', 'invoice:id,number'])->orderByDesc('paid_at')->take(200)->get()->map(fn ($installment) => [
            'id' => $installment->id,
            'project_id' => $installment->project_id,
            'project' => $installment->project?->name ?? '—',
            'client_id' => $installment->client_id,
            'client' => $installment->client?->name ?? '—',
            'invoice_id' => $installment->invoice_id,
            'invoice' => $installment->invoice?->number ?? '—',
            'amount' => (float) $installment->amount,
            'note' => $installment->note,
            'paid_at' => $installment->paid_at?->toDateString(),
        ])->toArray();
        $invoices = Invoice::query()->orderByDesc('issued_at')->take(500)->get(['id', 'project_id', 'client_id', 'number', 'total', 'status', 'issued_at'])->map(fn ($invoice) => [
            'id' => $invoice->id,
            'project_id' => $invoice->project_id,
            'client_id' => $invoice->client_id,
            'number' => $invoice->number,
            'total' => (float) $invoice->total,
            'status' => $invoice->status,
            'issued_at' => $invoice->issued_at?->toDateString(),
        ])->toArray();

        return $this->success([
            'sales' => $sales,
            'projects' => $projects,
            'installments' => $installments,
            'invoices' => $invoices,
        ]);
    }

    public function storeInstallment(Request $request): JsonResponse
    {
        $data = $request->validate([
            'project_id' => ['required', 'integer', 'exists:projects,id'],
            'amount' => ['required', 'numeric', 'min:0.01'],
            'note' => ['nullable', 'string', 'max:500'],
            'paid_at' => ['nullable', 'date'],
            'invoice_id' => ['nullable', 'integer', 'exists:invoices,id'],
        ]);

        $project = Project::with('client')->findOrFail($data['project_id']);

        if (! empty($data['invoice_id'])) {
            $invoice = Invoice::findOrFail($data['invoice_id']);
            $sameClient = (int) $invoice->client_id === (int) $project->client_id;
            $sameProject = ! $invoice->project_id || (int) $invoice->project_id === (int) $project->id;
            if (! $sameClient || ! $sameProject) {
                return $this->error('A fatura selecionada nao corresponde ao projeto ou cliente.', ['invoice_id' => ['A fatura selecionada nao corresponde ao projeto ou cliente.']], 422);
            }
        }

        $installment = Installment::create([
            'project_id' => $project->id,
            'client_id' => $project->client_id,
            'invoice_id' => $data['invoice_id'] ?? null,
            'amount' => $data['amount'],
            'note' => $data['note'] ?? null,
            'paid_at' => $data['paid_at'] ?? now()->toDateString(),
        ]);

        return $this->success(['installment' => $installment], 'Parcela registada.', 201);
    }

    public function destroyInstallment(Installment $installment): JsonResponse
    {
        $installment->delete();

        return $this->success([], 'Parcela removida.');
    }

    public function updateInstallment(Request $request, string $type, int $id): JsonResponse
    {
        $data = $request->validate([
            'is_installment' => ['required', 'boolean'],
            'installment_count' => ['nullable', 'integer', 'min:2'],
        ]);

        $count = null;
        if ($data['is_installment']) {
            $count = (int) ($data['installment_count'] ?? 0);
            if ($count < 2) {
                return $this->error('Indica o numero de parcelas.', ['installment_count' => ['Indica o numero de parcelas.']], 422);
            }
        }

        if ($type === 'invoice') {
            $invoice = Invoice::findOrFail($id);
            $invoice->is_installment = $data['is_installment'];
            $invoice->installment_count = $count;
            $invoice->save();

            return $this->success(['invoice' => $invoice], 'Configuração de parcelas atualizada.');
        }

        if ($type === 'transaction') {
            $transaction = WalletTransaction::findOrFail($id);
            $transaction->is_installment = $data['is_installment'];
            $transaction->installment_count = $count;
            $transaction->save();

            return $this->success(['transaction' => $transaction], 'Configuração de parcelas atualizada.');
        }

        abort(404);
    }

    public function updateToInvoice(Request $request, int $id): JsonResponse
    {
        $data = $request->validate([
            'to_invoice' => ['required', 'boolean'],
        ]);

        $transaction = WalletTransaction::with('wallet')->findOrFail($id);
        $shouldInvoice = (bool) $data['to_invoice'];

        if ($shouldInvoice && ! $transaction->invoice_id) {
            if (! $transaction->wallet?->client_id) {
                return $this->error('Nao foi possivel encontrar o cliente para faturar.', ['to_invoice' => ['Nao foi possivel encontrar o cliente para faturar.']], 422);
            }

            $invoice = $this->createInvoiceForTransaction($transaction);
            $transaction->invoice_id = $invoice->id;
        }

        if (! $shouldInvoice && $transaction->invoice_id) {
            $this->removeTransactionFromInvoice($transaction);
        }

        $transaction->to_invoice = $shouldInvoice;
        $transaction->save();

        return $this->success(['transaction' => $transaction], 'Estado de faturação atualizado.');
    }

    public function updateProjectToInvoice(Request $request, int $id): JsonResponse
    {
        $data = $request->validate([
            'to_invoice' => ['required', 'boolean'],
        ]);

        $project = Project::with(['quote', 'invoice', 'invoice.items'])->findOrFail($id);
        $shouldInvoice = (bool) $data['to_invoice'];

        if ($shouldInvoice && ! $project->invoice) {
            $invoice = $this->createInvoiceForProject($project);

            return $this->success(['invoice' => $invoice], 'Projeto faturado.');
        }

        if (! $shouldInvoice && $project->invoice) {
            $this->removeProjectFromInvoice($project);
        }

        return $this->success([], 'Estado de faturação do projeto atualizado.');
    }

    public function bulkUninvoice(Request $request): JsonResponse
    {
        $data = $request->validate([
            'items' => ['required', 'array', 'min:1'],
            'items.*.source' => ['required', 'in:project,transaction'],
            'items.*.id' => ['required', 'integer'],
        ]);

        $items = collect($data['items']);
        $projectIds = $items->where('source', 'project')->pluck('id')->all();
        $transactionIds = $items->where('source', 'transaction')->pluck('id')->all();

        $projects = Project::with(['invoice', 'invoice.items'])->whereIn('id', $projectIds)->get();
        $transactions = WalletTransaction::with(['wallet'])->whereIn('id', $transactionIds)->get();

        foreach ($projects as $project) {
            if ($project->invoice) {
                $this->removeProjectFromInvoice($project);
            }
        }

        foreach ($transactions as $transaction) {
            if ($transaction->invoice_id) {
                $this->removeTransactionFromInvoice($transaction);
            }
        }

        return $this->success([], 'Faturacao removida.');
    }

    public function bulkToInvoice(Request $request): JsonResponse
    {
        $data = $request->validate([
            'items' => ['required', 'array', 'min:1'],
            'items.*.source' => ['required', 'in:project,transaction'],
            'items.*.id' => ['required', 'integer'],
        ]);

        $items = collect($data['items']);
        $projectIds = $items->where('source', 'project')->pluck('id')->all();
        $transactionIds = $items->where('source', 'transaction')->pluck('id')->all();

        $projects = Project::with(['client', 'quote', 'invoice', 'invoice.items'])->whereIn('id', $projectIds)->get();
        $transactions = WalletTransaction::with(['wallet'])->whereIn('id', $transactionIds)->get();

        $clientIds = collect([])
            ->merge($projects->pluck('client_id'))
            ->merge($transactions->map(fn ($transaction) => $transaction->wallet?->client_id))
            ->filter()
            ->unique();

        if ($clientIds->count() > 1) {
            return $this->error('Seleciona vendas do mesmo cliente.', ['bulk' => ['Seleciona vendas do mesmo cliente.']], 422);
        }

        if ($projects->count() > 1) {
            return $this->error('Seleciona apenas um projeto de cada vez.', ['bulk' => ['Seleciona apenas um projeto de cada vez.']], 422);
        }

        $targetInvoice = null;
        $project = $projects->first();

        if ($project) {
            if ($project->invoice) {
                $targetInvoice = $project->invoice->load('items');
                if ($targetInvoice->items->isEmpty()) {
                    $this->ensureProjectItem($targetInvoice, $project);
                }
            } else {
                $targetInvoice = $this->createInvoiceForProject($project);
            }
        } elseif ($clientIds->isNotEmpty()) {
            $targetInvoice = $this->createInvoiceForClient((int) $clientIds->first());
        }

        if (! $targetInvoice) {
            return $this->error('Nao foi possivel criar a fatura.', ['bulk' => ['Nao foi possivel criar a fatura.']], 422);
        }

        foreach ($transactions as $transaction) {
            if ($transaction->invoice_id && $transaction->invoice_id !== $targetInvoice->id) {
                continue;
            }

            if (! $transaction->wallet?->client_id) {
                continue;
            }

            if (! $transaction->invoice_id) {
                $this->addTransactionToInvoice($targetInvoice, $transaction);
            }
        }

        $this->recalculateInvoice($targetInvoice);

        return $this->success(['invoice' => $targetInvoice->fresh('items')], 'Faturas criadas.');
    }

    private function createInvoiceForTransaction(WalletTransaction $transaction): Invoice
    {
        $invoice = $this->createInvoiceForClient($transaction->wallet->client_id);
        $this->addTransactionToInvoice($invoice, $transaction);
        $this->recalculateInvoice($invoice);

        return $invoice;
    }

    private function createInvoiceForProject(Project $project): Invoice
    {
        $total = $this->calculateQuoteTotal($project->quote);
        $invoice = Invoice::create([
            'project_id' => $project->id,
            'client_id' => $project->client_id,
            'number' => Invoice::generateNumber(),
            'total' => $total,
            'status' => 'pendente',
            'issued_at' => now(),
            'due_at' => now()->addDays(10),
            'paid_at' => null,
        ]);

        $invoice->items()->create([
            'description' => $project->name ?? 'Projeto',
            'quantity' => 1,
            'unit_price' => $total,
            'total' => $total,
            'source_type' => 'project',
            'source_id' => $project->id,
        ]);

        return $invoice;
    }

    private function createInvoiceForClient(int $clientId): Invoice
    {
        return Invoice::create([
            'client_id' => $clientId,
            'number' => Invoice::generateNumber(),
            'total' => 0,
            'status' => 'pendente',
            'issued_at' => now(),
            'due_at' => now()->addDays(10),
            'paid_at' => null,
        ]);
    }

    private function addTransactionToInvoice(Invoice $invoice, WalletTransaction $transaction): void
    {
        $total = (float) ($transaction->amount ?? 0);

        $invoice->items()->create([
            'description' => $transaction->description ?? ($transaction->product?->name ?? 'Venda de pack/produto'),
            'quantity' => 1,
            'unit_price' => $total,
            'total' => $total,
            'source_type' => 'transaction',
            'source_id' => $transaction->id,
        ]);

        $transaction->invoice_id = $invoice->id;
        $transaction->to_invoice = true;
        $transaction->save();
    }

    private function removeTransactionFromInvoice(WalletTransaction $transaction): void
    {
        if (! $transaction->invoice_id) {
            $transaction->to_invoice = false;
            $transaction->save();

            return;
        }

        $invoice = Invoice::with('items')->find($transaction->invoice_id);
        if ($invoice) {
            $invoice->items()->where('source_type', 'transaction')->where('source_id', $transaction->id)->delete();

            if ($invoice->items()->count() === 0) {
                $invoice->delete();
            } else {
                $this->recalculateInvoice($invoice);
            }
        }

        $transaction->invoice_id = null;
        $transaction->to_invoice = false;
        $transaction->save();
    }

    private function ensureProjectItem(Invoice $invoice, Project $project): void
    {
        $total = $invoice->total ?? $this->calculateQuoteTotal($project->quote);

        $invoice->items()->create([
            'description' => $project->name ?? 'Projeto',
            'quantity' => 1,
            'unit_price' => (float) $total,
            'total' => (float) $total,
            'source_type' => 'project',
            'source_id' => $project->id,
        ]);
    }

    private function removeProjectFromInvoice(Project $project): void
    {
        if (! $project->invoice) {
            return;
        }

        $invoice = $project->invoice->load('items');
        $invoice->items()->where('source_type', 'project')->where('source_id', $project->id)->delete();

        if ($invoice->items()->count() === 0) {
            $invoice->delete();
        } else {
            $invoice->project_id = null;
            $invoice->save();
            $this->recalculateInvoice($invoice);
        }
    }

    private function recalculateInvoice(Invoice $invoice): void
    {
        $invoice->total = (float) $invoice->items()->sum('total');
        $invoice->save();
    }

    private function calculateQuoteTotal(?Quote $quote): float
    {
        if (! $quote) {
            return 0;
        }

        $total = (float) ($quote->price_development ?? 0);
        $total += (float) ($quote->price_maintenance_monthly ?? 0);
        if ($quote->include_domain) {
            $total += (float) ($quote->price_domain_first_year ?? 0);
        }
        if ($quote->include_hosting) {
            $total += (float) ($quote->price_hosting_first_year ?? 0);
        }

        return $total;
    }
}
