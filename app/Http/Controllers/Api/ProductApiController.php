<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Api\Concerns\RespondsWithJson;
use App\Http\Controllers\Controller;
use App\Http\Resources\Api\ProductResource;
use App\Models\PackItem;
use App\Models\Product;
use App\Models\ProductMeta;
use Barryvdh\DomPDF\Facade\Pdf;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

class ProductApiController extends Controller
{
    use RespondsWithJson;

    public function index(Request $request): JsonResponse
    {
        $type = $request->get('type');

        $products = Product::with(['packItems', 'meta'])
            ->when($type, fn ($q) => $q->where('type', $type))
            ->latest()
            ->get();

        return $this->success([
            'products' => ProductResource::collection($products),
            'type' => $type,
        ]);
    }

    public function show(Product $product): JsonResponse
    {
        $product->load(['packItems', 'meta']);

        return $this->success([
            'product' => new ProductResource($product),
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        $product = $this->persistProduct($request);

        return $this->success([
            'product' => new ProductResource($product->load(['packItems', 'meta'])),
        ], 'Produto criado com sucesso.', 201);
    }

    public function update(Request $request, Product $product): JsonResponse
    {
        $product = $this->persistProduct($request, $product);

        return $this->success([
            'product' => new ProductResource($product->load(['packItems', 'meta'])),
        ], 'Produto atualizado com sucesso.');
    }

    public function destroy(Product $product): JsonResponse
    {
        $product->delete();

        return $this->success([], 'Produto removido com sucesso.');
    }

    public function updatePaymentMethodsVisibility(Request $request, Product $product): JsonResponse
    {
        $data = $request->validate([
            'show_payment_methods' => ['required', 'boolean'],
        ]);

        $product->update([
            'show_payment_methods' => (bool) $data['show_payment_methods'],
        ]);

        return $this->success([
            'product' => new ProductResource($product->fresh()),
        ], 'Visibilidade de métodos de pagamento atualizada.');
    }

    public function pdf(Product $product)
    {
        $product->load(['meta', 'packItems']);

        $pdf = Pdf::loadView('pdf.product', [
            'product' => $product,
            'company' => \App\Support\CompanySettings::get(),
        ])->setPaper('a4');

        return $pdf->stream("produto-{$product->slug}.pdf");
    }

    private function persistProduct(Request $request, ?Product $product = null): Product
    {
        $data = $request->validate([
            'type' => 'required|in:product,pack',
            'name' => 'required|string|max:255',
            'price' => 'nullable|numeric',
            'short_description' => 'nullable|string',
            'content_html' => 'nullable|string',
            'pack_items' => 'array',
            'pack_items.*.hours' => 'nullable|numeric',
            'pack_items.*.normal_price' => 'nullable|numeric',
            'pack_items.*.pack_price' => 'nullable|numeric',
            'pack_items.*.validity_months' => 'nullable|numeric',
            'pack_items.*.featured' => 'nullable|boolean',
            'info_fields' => 'array',
            'info_fields.*.type' => 'required|in:text,textarea,html,boolean',
            'info_fields.*.label' => 'nullable|string|max:255',
            'info_fields.*.value' => 'nullable',
        ]);

        if ($data['type'] === 'pack') {
            $data['price'] = null;
        }

        if (! $product) {
            $product = Product::create([
                'type' => $data['type'],
                'name' => $data['name'],
                'slug' => Str::slug($data['name']),
                'short_description' => $data['short_description'] ?? null,
                'content_html' => $data['content_html'] ?? null,
                'price' => $data['price'] ?? null,
                'active' => true,
            ]);
        } else {
            $product->update([
                'type' => $data['type'],
                'name' => $data['name'],
                'slug' => Str::slug($data['name']),
                'short_description' => $data['short_description'] ?? null,
                'content_html' => $data['content_html'] ?? null,
                'price' => $data['price'] ?? null,
            ]);

            PackItem::where('product_id', $product->id)->delete();
            ProductMeta::where('product_id', $product->id)->delete();
        }

        if ($product->type === 'pack') {
            foreach (($data['pack_items'] ?? []) as $i => $item) {
                PackItem::create([
                    'product_id' => $product->id,
                    'hours' => $item['hours'] ?? null,
                    'normal_price' => $item['normal_price'] ?? null,
                    'pack_price' => $item['pack_price'] ?? null,
                    'validity_months' => $item['validity_months'] ?? null,
                    'featured' => (bool) ($item['featured'] ?? false),
                    'order' => $i,
                ]);
            }
        }

        foreach (($data['info_fields'] ?? []) as $i => $field) {
            $label = trim((string) ($field['label'] ?? ''));
            if ($label === '') {
                continue;
            }

            ProductMeta::create([
                'product_id' => $product->id,
                'label' => $label,
                'key' => Str::slug($label),
                'type' => $field['type'],
                'value' => is_bool($field['value'] ?? null) ? (($field['value'] ?? false) ? '1' : '0') : ($field['value'] ?? null),
                'show_front' => true,
                'order' => $i,
            ]);
        }

        return $product;
    }
}
