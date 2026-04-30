<?php

namespace App\Http\Controllers;

use App\Http\Controllers\Concerns\InteractsWithClientPortalUsers;
use App\Http\Requests\StoreProjectRequest;
use App\Models\Client;
use App\Models\ProjectMessage;
use App\Models\Product;
use App\Models\Project;
use App\Models\Quote;
use App\Models\QuoteProduct;
use App\Support\ProjectCredentialObjectManager;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Inertia\Inertia;
use Inertia\Response;

class ProjectController extends Controller
{
    use InteractsWithClientPortalUsers;

    public function index(Request $request): Response
    {
        $statusOptions = [
            ['value' => 'planeamento', 'label' => 'Planeamento'],
            ['value' => 'em_andamento', 'label' => 'Em Andamento'],
            ['value' => 'aguardar_conteudos', 'label' => 'Aguardar Conteúdos'],
            ['value' => 'em_revisao', 'label' => 'Em Revisão'],
            ['value' => 'concluido', 'label' => 'Concluído'],
            ['value' => 'pausado', 'label' => 'Pausado'],
            ['value' => 'cancelado', 'label' => 'Cancelado'],
        ];

        $allowedStatuses = collect($statusOptions)->pluck('value')->all();
        $status = $request->query('status');
        $currentStatus = in_array($status, $allowedStatuses, true) ? $status : null;

        $projects = $this->scopeByClient(Project::with(['client', 'quote', 'invoice'])->withSum('installments', 'amount')->where('is_hidden', false))
            ->when($currentStatus, fn ($query) => $query->where('status', $currentStatus))
            ->latest()
            ->paginate(15)
            ->withQueryString();

        $statusCounts = $this->scopeByClient(Project::select('status', DB::raw('count(*) as total'))->where('is_hidden', false))
            ->groupBy('status')
            ->pluck('total', 'status');

        $statusFilters = collect($statusOptions)
            ->map(fn ($option) => [
                'value' => $option['value'],
                'label' => $option['label'],
                'count' => (int) ($statusCounts[$option['value']] ?? 0),
            ])
            ->values();

        return Inertia::render('Projects/Index', [
            'projects' => $projects,
            'statusFilters' => $statusFilters,
            'currentStatus' => $currentStatus,
            'totalCount' => $this->scopeByClient(Project::query()->where('is_hidden', false))->count(),
        ]);
    }

    public function create(): Response
    {
        $this->abortIfClientUser();

        $clients = Client::orderBy('name')->get(['id', 'name', 'company']);

        // catálogo (para importar)
        $products = Product::with(['packItems', 'meta'])
            ->where('active', true)
            ->orderBy('type')
            ->orderBy('name')
            ->get()
            ->map(function ($p) {
                return [
                    'id' => $p->id,
                    'type' => $p->type,
                    'name' => $p->name,
                    'slug' => $p->slug,
                    'short_description' => $p->short_description,
                    'content_html' => $p->content_html,
                    'price' => $p->price,

                    'pack_items' => $p->packItems->sortBy('order')->values()->map(fn ($i) => [
                        'hours' => $i->hours,
                        'normal_price' => $i->normal_price,
                        'pack_price' => $i->pack_price,
                        'validity_months' => $i->validity_months,
                        'featured' => (bool) $i->featured,
                    ])->toArray(),

                    'info_fields' => $p->meta->sortBy('order')->values()->map(fn ($m) => [
                        'type' => $m->type,
                        'label' => $m->label,
                        'value' => $m->value,
                    ])->toArray(),
                ];
            });

        return Inertia::render('Projects/Create', [
            'clients' => $clients,
            'defaultTerms' => $this->getLastTerms(),
            'catalog' => $products,
        ]);
    }

    public function show(Project $project): RedirectResponse
    {
        $this->ensureProjectOwnership($project);

        if ($this->isClientUser()) {
            return redirect()->route('projects.index');
        }

        return redirect()->route('projects.edit', $project);
    }

    public function store(StoreProjectRequest $request, ProjectCredentialObjectManager $objectManager): RedirectResponse
    {
        $this->abortIfClientUser();

        $data = $request->validated();
        $includeDomain = (bool) ($data['include_domain'] ?? false);
        $includeHosting = (bool) ($data['include_hosting'] ?? false);
        $domainFirstYear = $includeDomain ? (float) ($data['price_domain_first_year'] ?? 0) : 0;
        $domainOtherYears = $includeDomain ? (float) ($data['price_domain_other_years'] ?? 0) : 0;
        $hostingFirstYear = $includeHosting ? (float) ($data['price_hosting_first_year'] ?? 0) : 0;
        $hostingOtherYears = $includeHosting ? (float) ($data['price_hosting_other_years'] ?? 0) : 0;

        $author = request()->user();

        DB::transaction(function () use (&$project, $data, $includeDomain, $includeHosting, $domainFirstYear, $domainOtherYears, $hostingFirstYear, $hostingOtherYears, $objectManager, $author) {

            $project = Project::create([
                'client_id' => $data['client_id'],
                'name' => $data['name'],
                'type' => $data['type'] === 'outro'
                    ? ($data['custom_type'] ?? 'Outro')
                    : $data['type'],
                'status' => $data['status'],
            ]);

            $quote = Quote::create([
                'project_id' => $project->id,
                'project_type' => $project->type,
                'technologies' => $data['technologies'] ?? '',
                'description' => $data['description'] ?? '',
                'development_items' => $data['development_items'],
                'development_total_hours' => $data['development_total_hours'],
                'price_development' => $data['price_development'],

                'price_maintenance_monthly' => $data['price_maintenance_monthly'] ?? null,

                // FLAGS
                'include_domain' => $includeDomain,
                'include_hosting' => $includeHosting,

                // DOMÍNIO
                'price_domain_first_year' => $domainFirstYear,
                'price_domain_other_years' => $domainOtherYears,

                // ALOJAMENTO
                'price_hosting_first_year' => $hostingFirstYear,
                'price_hosting_other_years' => $hostingOtherYears,

                // 👉 ESTES DOIS CAMPOS FALTAVAM (PDF)
                'price_domains' => $domainFirstYear,
                'price_hosting' => $hostingFirstYear,

                'terms' => $data['terms'] ?? '',
            ]);

            $project->update(['quote_id' => $quote->id]);

            // imports -> snapshot na quote_products
            foreach (($data['imports'] ?? []) as $i => $imp) {
                QuoteProduct::create([
                    'quote_id' => $quote->id,
                    'product_id' => $imp['product_id'] ?? null,
                    'type' => $imp['type'],
                    'name' => $imp['name'],
                    'slug' => $imp['slug'] ?? null,
                    'short_description' => $imp['short_description'] ?? null,
                    'content_html' => $imp['content_html'] ?? null,
                    'price' => $imp['price'] ?? null,
                    'pack_items' => $imp['pack_items'] ?? null,
                    'info_fields' => $imp['info_fields'] ?? null,
                    'order' => $i,
                ]);
            }

            $objectManager->syncForProject($project);
            $this->logProjectStatusMessage($project, null, $author?->id, $author?->role, true);

        });

        return redirect()->route('projects.index')->with('success', 'Projeto e orçamento criados com sucesso.');
    }

    public function edit(Project $project): Response
    {
        $this->ensureProjectOwnership($project);
        $this->abortIfClientUser();

        $project->load(['client', 'quote', 'invoice', 'quote.quoteProducts', 'messages.user']);

        $clients = Client::orderBy('name')->get(['id', 'name', 'company']);

        $products = Product::with(['packItems', 'meta'])
            ->where('active', true)
            ->orderBy('type')
            ->orderBy('name')
            ->get()
            ->map(function ($p) {
                return [
                    'id' => $p->id,
                    'type' => $p->type,
                    'name' => $p->name,
                    'slug' => $p->slug,
                    'short_description' => $p->short_description,
                    'content_html' => $p->content_html,
                    'price' => $p->price,
                    'pack_items' => $p->packItems->sortBy('order')->values()->map(fn ($i) => [
                        'hours' => $i->hours,
                        'normal_price' => $i->normal_price,
                        'pack_price' => $i->pack_price,
                        'validity_months' => $i->validity_months,
                        'featured' => (bool) $i->featured,
                    ])->toArray(),
                    'info_fields' => $p->meta->sortBy('order')->values()->map(fn ($m) => [
                        'type' => $m->type,
                        'label' => $m->label,
                        'value' => $m->value,
                    ])->toArray(),
                ];
            });

        return Inertia::render('Projects/Edit', [
            'project' => $project,
            'clients' => $clients,
            'catalog' => $products,
        ]);
    }

    public function update(StoreProjectRequest $request, Project $project, ProjectCredentialObjectManager $objectManager): RedirectResponse
    {
        $this->ensureProjectOwnership($project);
        $this->abortIfClientUser();

        $data = $request->validated();
        $includeDomain = (bool) ($data['include_domain'] ?? false);
        $includeHosting = (bool) ($data['include_hosting'] ?? false);
        $domainFirstYear = $includeDomain ? (float) ($data['price_domain_first_year'] ?? 0) : 0;
        $domainOtherYears = $includeDomain ? (float) ($data['price_domain_other_years'] ?? 0) : 0;
        $hostingFirstYear = $includeHosting ? (float) ($data['price_hosting_first_year'] ?? 0) : 0;
        $hostingOtherYears = $includeHosting ? (float) ($data['price_hosting_other_years'] ?? 0) : 0;

        $author = request()->user();

        DB::transaction(function () use ($project, $data, $includeDomain, $includeHosting, $domainFirstYear, $domainOtherYears, $hostingFirstYear, $hostingOtherYears, $objectManager, $author) {
            $previousStatus = $project->status;

            $project->update([
                'client_id' => $data['client_id'],
                'name' => $data['name'],
                'type' => $data['type'] === 'outro'
                    ? ($data['custom_type'] ?? 'Outro')
                    : $data['type'],
                'status' => $data['status'],
            ]);

            $quote = $project->quote;
            if ($quote) {
                $quote->update([
                    'project_type' => $project->type,
                    'technologies' => $data['technologies'] ?? '',
                    'description' => $data['description'] ?? '',
                    'development_items' => $data['development_items'],
                    'development_total_hours' => $data['development_total_hours'],
                    'price_development' => $data['price_development'],

                    'price_maintenance_monthly' => $data['price_maintenance_monthly'] ?? null,

                    // FLAGS
                    'include_domain' => $includeDomain,
                    'include_hosting' => $includeHosting,

                    // DOMÍNIO
                    'price_domain_first_year' => $domainFirstYear,
                    'price_domain_other_years' => $domainOtherYears,

                    // ALOJAMENTO
                    'price_hosting_first_year' => $hostingFirstYear,
                    'price_hosting_other_years' => $hostingOtherYears,

                    // 👉 ESTES DOIS CAMPOS SÃO O QUE O PDF USA
                    'price_domains' => $domainFirstYear,
                    'price_hosting' => $hostingFirstYear,

                    'terms' => $data['terms'] ?? '',
                ]);

                // regravar imports
                QuoteProduct::where('quote_id', $quote->id)->delete();

                foreach (($data['imports'] ?? []) as $i => $imp) {
                    QuoteProduct::create([
                        'quote_id' => $quote->id,
                        'product_id' => $imp['product_id'] ?? null,
                        'type' => $imp['type'],
                        'name' => $imp['name'],
                        'slug' => $imp['slug'] ?? null,
                        'short_description' => $imp['short_description'] ?? null,
                        'content_html' => $imp['content_html'] ?? null,
                        'price' => $imp['price'] ?? null,
                        'pack_items' => $imp['pack_items'] ?? null,
                        'info_fields' => $imp['info_fields'] ?? null,
                        'order' => $i,
                    ]);
                }
            }

            $objectManager->syncForProject($project);
            $this->logProjectStatusMessage($project, $previousStatus, $author?->id, $author?->role, false);

        });

        return redirect()->route('projects.index')->with('success', 'Projeto atualizado com sucesso.');
    }

    public function destroy(Project $project): RedirectResponse
    {
        $this->ensureProjectOwnership($project);
        $this->abortIfClientUser();

        DB::transaction(function () use ($project) {
            if ($project->invoice) {
                $project->invoice->delete();
            }

            $project->delete();
        });

        return redirect()->route('projects.index')->with('success', 'Projeto removido com sucesso.');
    }

    private function getLastTerms(): string
    {
        return Quote::whereNotNull('terms')
            ->orderByDesc('id')
            ->value('terms')
            ?? $this->defaultTerms();
    }

    private function defaultTerms(): string
    {
        return <<<'TEXT'
• Prazo de entrega: ≈ 10–15 dias úteis

• Prazo de Garantia:
  - O cliente terá um período de 3 semanas para testar a aplicação em produção.
  - Durante esse período, quaisquer problemas ou falhas técnicas relacionadas às funcionalidades acordadas serão corrigidas sem custos adicionais.
  - A garantia não cobre novas funcionalidades ou alterações fora do escopo.
  - Após o período de garantia, qualquer ajuste será orçamentado separadamente.

TEXT;
    }

    private function logProjectStatusMessage(Project $project, ?string $previousStatus, ?int $userId, ?string $senderRole, bool $isNew): void
    {
        $currentStatus = $project->status;
        if (! $isNew && $previousStatus === $currentStatus) {
            return;
        }

        ProjectMessage::create([
            'project_id' => $project->id,
            'user_id' => $userId,
            'sender_role' => $senderRole,
            'type' => 'status_update',
            'body' => $isNew
                ? 'Projeto criado com o estado '.$this->statusLabel($currentStatus).'.'
                : 'Estado alterado para '.$this->statusLabel($currentStatus).'.',
            'meta' => [
                'previous_status' => $previousStatus,
                'current_status' => $currentStatus,
            ],
        ]);
    }

    private function statusLabel(?string $status): string
    {
        return match ($status) {
            'planeamento' => 'Planeamento',
            'em_andamento' => 'Em Andamento',
            'aguardar_conteudos' => 'Aguardar Conteúdos',
            'em_revisao' => 'Em Revisão',
            'concluido' => 'Concluído',
            'pausado' => 'Pausado',
            'cancelado' => 'Cancelado',
            default => $status ?: 'Sem estado',
        };
    }
}
