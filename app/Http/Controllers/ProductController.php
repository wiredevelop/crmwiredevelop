<?php

namespace App\Http\Controllers;

use App\Models\Product;
use App\Models\ProductMeta;
use App\Models\PackItem;
use Illuminate\Http\Request;
use Illuminate\Support\Str;
use Inertia\Inertia;

class ProductController extends Controller
{
    public function index(Request $request)
    {
        $type = $request->get('type');

        $products = Product::when($type, fn($q) => $q->where('type', $type))
            ->latest()
            ->get();

        return Inertia::render('Products/Index', [
            'products' => $products,
            'type' => $type,
        ]);
    }

    public function create()
    {
        return Inertia::render('Products/Create');
    }

    public function store(Request $request)
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

        // Packs não têm price direto
        if ($data['type'] === 'pack') {
            $data['price'] = null;
        }

        $product = Product::create([
            'type' => $data['type'],
            'name' => $data['name'],
            'slug' => Str::slug($data['name']),
            'short_description' => $data['short_description'] ?? null,
            'content_html' => $data['content_html'] ?? null,
            'price' => $data['price'] ?? null,
            'active' => true,
        ]);

        // Guardar linhas do pack
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

        // regravar meta
        ProductMeta::where('product_id', $product->id)->delete();

        foreach (($data['info_fields'] ?? []) as $i => $field) {
            $label = trim((string) ($field['label'] ?? ''));
            if ($label === '') {
                continue;
            }

            ProductMeta::create([
                'product_id' => $product->id, // ✅ agora funciona
                'label' => $label,
                'key' => Str::slug($label),
                'type' => $field['type'],
                'value' => is_bool($field['value'] ?? null)
                    ? (($field['value'] ?? false) ? '1' : '0')
                    : ($field['value'] ?? null),
                'show_front' => true,
                'order' => $i,
            ]);
        }

        // 🔁 voltar à lista
        return redirect()->route('products.index');
    }

    public function edit(Product $product)
    {
        $product->load(['packItems', 'meta']);

        return Inertia::render('Products/Edit', [
            'product' => [
                'id' => $product->id,
                'type' => $product->type,
                'name' => $product->name,
                'price' => $product->price,
                'short_description' => $product->short_description,
                'content_html' => $product->content_html,

                // exatamente o que o Create usa
                'pack_items' => $product->packItems->map(fn($item) => [
                    'hours' => $item->hours,
                    'normal_price' => $item->normal_price,
                    'pack_price' => $item->pack_price,
                    'validity_months' => $item->validity_months,
                    'featured' => (bool) $item->featured,
                ]),

                'info_fields' => $product->meta->map(fn($meta) => [
                    'type' => $meta->type,
                    'label' => $meta->label,
                    'value' => $meta->value,
                ]),
            ],
        ]);
    }

    public function update(Request $request, Product $product)
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

        // Packs não têm price direto
        if ($data['type'] === 'pack') {
            $data['price'] = null;
        }

        $product->update([
            'type' => $data['type'],
            'name' => $data['name'],
            'slug' => Str::slug($data['name']),
            'short_description' => $data['short_description'] ?? null,
            'content_html' => $data['content_html'] ?? null,
            'price' => $data['price'] ?? null,
        ]);

        // regravar pack items
        PackItem::where('product_id', $product->id)->delete();
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

        // regravar meta
        ProductMeta::where('product_id', $product->id)->delete();
        foreach (($data['info_fields'] ?? []) as $i => $field) {
            $label = trim((string) ($field['label'] ?? ''));
            if ($label === '')
                continue;

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

        return redirect()->route('products.index');
    }

    public function destroy(Product $product)
    {
        $product->delete();
        return redirect()->route('products.index');
    }

    public function updatePaymentMethodsVisibility(Request $request, Product $product)
    {
        $data = $request->validate([
            'show_payment_methods' => ['required', 'boolean'],
        ]);

        $product->update([
            'show_payment_methods' => (bool) $data['show_payment_methods'],
        ]);

        return redirect()->back();
    }

    // PDF
    public function pdf(Product $product)
    {
        $product->load(['meta', 'packItems']);

        // requer dompdf (ver abaixo)
        $pdf = \Barryvdh\DomPDF\Facade\Pdf::loadView('pdf.product', [
            'product' => $product,
            'company' => \App\Support\CompanySettings::get(),
        ])->setPaper('a4');

        return $pdf->stream("produto-{$product->slug}.pdf");
    }
}
