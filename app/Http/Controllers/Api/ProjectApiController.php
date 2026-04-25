<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Api\Concerns\RespondsWithJson;
use App\Http\Controllers\Controller;
use App\Http\Requests\StoreProjectRequest;
use App\Http\Resources\Api\ClientCredentialResource;
use App\Http\Resources\Api\ProjectResource;
use App\Models\Client;
use App\Models\ClientCredential;
use App\Models\Product;
use App\Models\Project;
use App\Models\Quote;
use App\Models\QuoteProduct;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class ProjectApiController extends Controller
{
    use RespondsWithJson;

    public function index(Request $request): JsonResponse
    {
        $statusOptions = $this->statusOptions();
        $allowedStatuses = collect($statusOptions)->pluck('value')->all();
        $status = $request->query('status');
        $currentStatus = in_array($status, $allowedStatuses, true) ? $status : null;

        $projects = Project::with(['client', 'quote', 'invoice'])
            ->where('is_hidden', false)
            ->when($currentStatus, fn ($query) => $query->where('status', $currentStatus))
            ->latest()
            ->paginate((int) $request->integer('per_page', 15))
            ->withQueryString();

        $statusCounts = Project::select('status', DB::raw('count(*) as total'))
            ->where('is_hidden', false)
            ->groupBy('status')
            ->pluck('total', 'status');

        $statusFilters = collect($statusOptions)->map(fn ($option) => [
            'value' => $option['value'],
            'label' => $option['label'],
            'count' => (int) ($statusCounts[$option['value']] ?? 0),
        ])->values()->toArray();

        return $this->paginated($request, $projects, ProjectResource::collection($projects->getCollection())->resolve(), null, [
            'status_filters' => $statusFilters,
            'current_status' => $currentStatus,
            'total_count' => Project::where('is_hidden', false)->count(),
        ]);
    }

    public function options(): JsonResponse
    {
        return $this->success([
            'clients' => Client::orderBy('name')->get(['id', 'name', 'company']),
            'catalog' => $this->catalog(),
            'default_terms' => $this->getLastTerms(),
            'status_options' => $this->statusOptions(),
        ]);
    }

    public function show(Project $project, Request $request): JsonResponse
    {
        $project->load(['client', 'quote.quoteProducts', 'invoice', 'credentials']);

        $data = [
            'project' => new ProjectResource($project),
        ];

        if ($request->boolean('with_options')) {
            $data['clients'] = Client::orderBy('name')->get(['id', 'name', 'company']);
            $data['catalog'] = $this->catalog();
            $data['status_options'] = $this->statusOptions();
        }

        return $this->success($data);
    }

    public function store(StoreProjectRequest $request): JsonResponse
    {
        $project = $this->persistProject(null, $request->validated());

        return $this->success([
            'project' => new ProjectResource($project->load(['client', 'quote.quoteProducts', 'invoice'])),
        ], 'Projeto e orçamento criados com sucesso.', 201);
    }

    public function update(StoreProjectRequest $request, Project $project): JsonResponse
    {
        $project = $this->persistProject($project, $request->validated());

        return $this->success([
            'project' => new ProjectResource($project->load(['client', 'quote.quoteProducts', 'invoice'])),
        ], 'Projeto atualizado com sucesso.');
    }

    public function destroy(Project $project): JsonResponse
    {
        DB::transaction(function () use ($project) {
            if ($project->invoice) {
                $project->invoice->delete();
            }

            $project->delete();
        });

        return $this->success([], 'Projeto removido com sucesso.');
    }

    public function credentials(Project $project): JsonResponse
    {
        $project->load('client');
        $credentials = $project->credentials()->latest()->get();

        return $this->success([
            'project' => new ProjectResource($project),
            'credentials' => ClientCredentialResource::collection($credentials),
        ]);
    }

    public function storeCredential(Request $request, Project $project): JsonResponse
    {
        $data = $request->validate([
            'label' => ['required', 'string', 'max:150'],
            'username' => ['nullable', 'string', 'max:255'],
            'password' => ['required', 'string', 'max:65535'],
            'url' => ['nullable', 'string', 'max:255'],
            'notes' => ['nullable', 'string', 'max:65535'],
        ]);

        $credential = $project->credentials()->create(array_merge($data, [
            'client_id' => $project->client_id,
        ]));

        return $this->success([
            'credential' => new ClientCredentialResource($credential),
        ], 'Credencial criada com sucesso.', 201);
    }

    public function destroyCredential(Project $project, ClientCredential $credential): JsonResponse
    {
        abort_if($credential->project_id !== $project->id, 404);

        $credential->delete();

        return $this->success([], 'Credencial removida com sucesso.');
    }

    private function persistProject(?Project $project, array $data): Project
    {
        $includeDomain = (bool) ($data['include_domain'] ?? false);
        $includeHosting = (bool) ($data['include_hosting'] ?? false);
        $domainFirstYear = $includeDomain ? (float) ($data['price_domain_first_year'] ?? 0) : 0;
        $domainOtherYears = $includeDomain ? (float) ($data['price_domain_other_years'] ?? 0) : 0;
        $hostingFirstYear = $includeHosting ? (float) ($data['price_hosting_first_year'] ?? 0) : 0;
        $hostingOtherYears = $includeHosting ? (float) ($data['price_hosting_other_years'] ?? 0) : 0;

        return DB::transaction(function () use ($project, $data, $includeDomain, $includeHosting, $domainFirstYear, $domainOtherYears, $hostingFirstYear, $hostingOtherYears) {
            if (!$project) {
                $project = Project::create([
                    'client_id' => $data['client_id'],
                    'name' => $data['name'],
                    'type' => $data['type'] === 'outro' ? ($data['custom_type'] ?? 'Outro') : $data['type'],
                    'status' => $data['status'],
                ]);

                $quote = Quote::create($this->quotePayload($project, $data, $includeDomain, $includeHosting, $domainFirstYear, $domainOtherYears, $hostingFirstYear, $hostingOtherYears));
                $project->update(['quote_id' => $quote->id]);
            } else {
                $project->update([
                    'client_id' => $data['client_id'],
                    'name' => $data['name'],
                    'type' => $data['type'] === 'outro' ? ($data['custom_type'] ?? 'Outro') : $data['type'],
                    'status' => $data['status'],
                ]);

                $quote = $project->quote;
                if ($quote) {
                    $quote->update($this->quotePayload($project, $data, $includeDomain, $includeHosting, $domainFirstYear, $domainOtherYears, $hostingFirstYear, $hostingOtherYears));
                    QuoteProduct::where('quote_id', $quote->id)->delete();
                }
            }

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

            return $project;
        });
    }

    private function quotePayload(Project $project, array $data, bool $includeDomain, bool $includeHosting, float $domainFirstYear, float $domainOtherYears, float $hostingFirstYear, float $hostingOtherYears): array
    {
        return [
            'project_id' => $project->id,
            'project_type' => $project->type,
            'technologies' => $data['technologies'] ?? '',
            'description' => $data['description'] ?? '',
            'development_items' => $data['development_items'],
            'development_total_hours' => $data['development_total_hours'],
            'price_development' => $data['price_development'],
            'price_maintenance_monthly' => $data['price_maintenance_monthly'] ?? null,
            'include_domain' => $includeDomain,
            'include_hosting' => $includeHosting,
            'price_domain_first_year' => $domainFirstYear,
            'price_domain_other_years' => $domainOtherYears,
            'price_hosting_first_year' => $hostingFirstYear,
            'price_hosting_other_years' => $hostingOtherYears,
            'price_domains' => $domainFirstYear,
            'price_hosting' => $hostingFirstYear,
            'terms' => $data['terms'] ?? '',
        ];
    }

    private function catalog()
    {
        return Product::with(['packItems', 'meta'])
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
                        'id' => $i->id,
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
            })
            ->values();
    }

    private function getLastTerms(): string
    {
        return Quote::whereNotNull('terms')->orderByDesc('id')->value('terms') ?? $this->defaultTerms();
    }

    private function defaultTerms(): string
    {
        return <<<TEXT
• Prazo de entrega: ≈ 10–15 dias úteis

• Prazo de Garantia:
  - O cliente terá um período de 3 semanas para testar a aplicação em produção.
  - Durante esse período, quaisquer problemas ou falhas técnicas relacionadas às funcionalidades acordadas serão corrigidas sem custos adicionais.
  - A garantia não cobre novas funcionalidades ou alterações fora do escopo.
  - Após o período de garantia, qualquer ajuste será orçamentado separadamente.
TEXT;
    }

    private function statusOptions(): array
    {
        return [
            ['value' => 'planeamento', 'label' => 'Planeamento'],
            ['value' => 'em_andamento', 'label' => 'Em Andamento'],
            ['value' => 'aguardar_conteudos', 'label' => 'Aguardar Conteúdos'],
            ['value' => 'em_revisao', 'label' => 'Em Revisão'],
            ['value' => 'concluido', 'label' => 'Concluído'],
            ['value' => 'pausado', 'label' => 'Pausado'],
            ['value' => 'cancelado', 'label' => 'Cancelado'],
        ];
    }
}
