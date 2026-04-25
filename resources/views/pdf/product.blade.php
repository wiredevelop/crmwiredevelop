<!DOCTYPE html>
<html lang="pt">

<head>
    <meta charset="UTF-8">
    <title>{{ $product->name }} | WireDevelop</title>

    <style>
        @page {
            margin: 0;
        }

        body {
            font-family: DejaVu Sans, sans-serif;
            margin: 0;
            padding: 0;
            color: #1f2937;
            background: #ffffff;
        }

        /* HEADER */
        .header {
            background: #015557;
            color: #ffffff;
            padding: 32px 48px;
        }

        .header h1 {
            margin: 0;
            font-size: 26px;
            letter-spacing: 0.5px;
        }

        .header p {
            margin: 6px 0 0;
            font-size: 13px;
            opacity: 0.9;
        }

        /* CONTENT */
        .container {
            padding: 40px 48px 110px 48px;
        }

        h2 {
            font-size: 22px;
            margin-bottom: 8px;
            color: #015557;
        }

        .subtitle {
            color: #6b7280;
            font-size: 14px;
            margin-bottom: 32px;
        }

        .product-price {
            font-size: 24px;
            font-weight: 700;
            color: #015557;
            margin: 0 0 24px;
        }

        .content-card {
            border: 1px solid #e5e7eb;
            border-radius: 8px;
            padding: 24px;
            background: #ffffff;
            margin-bottom: 24px;
        }

        .content-card.plain-text {
            white-space: pre-line;
            line-height: 1.6;
        }

        .content-card p:first-child,
        .content-card ul:first-child,
        .content-card ol:first-child,
        .content-card h1:first-child,
        .content-card h2:first-child,
        .content-card h3:first-child {
            margin-top: 0;
        }

        .content-card p:last-child,
        .content-card ul:last-child,
        .content-card ol:last-child {
            margin-bottom: 0;
        }

        .content-card ul,
        .content-card ol {
            padding-left: 20px;
        }

        .content-card li {
            margin-bottom: 6px;
        }

        /* PACK CARDS */
        .pack-card {
            border: 1px solid #e5e7eb;
            border-left: 6px solid #015557;
            border-radius: 8px;
            padding: 20px 24px;
            margin-bottom: 20px;
            position: relative;
        }

        .pack-card.featured {
            border-left-color: #0f766e;
            background: #f0fdfa;
        }

        .badge {
            position: absolute;
            top: -10px;
            right: 16px;
            background: #015557;
            color: #ffffff;
            font-size: 11px;
            padding: 6px 10px;
            border-radius: 999px;
            letter-spacing: 0.3px;
        }

        .pack-title {
            font-size: 18px;
            font-weight: 700;
            margin-bottom: 12px;
        }

        .pack-details {
            width: 100%;
            border-collapse: collapse;
            font-size: 14px;
        }

        .pack-details td {
            padding: 6px 0;
        }

        .label {
            color: #6b7280;
        }

        .old-price {
            text-decoration: line-through;
            color: #9ca3af;
        }

        .price {
            font-size: 20px;
            font-weight: bold;
            color: #015557;
        }

        /* INFO FIELDS */
        .info-section {
            page-break-before: always;
            padding-top: 40px;
        }

        .info-section h3 {
            font-size: 18px;
            margin-bottom: 12px;
            color: #015557;
        }

        /* FOOTER */
        .footer {
            position: fixed;
            bottom: 0;
            width: 100%;
            background: #f9fafb;
            padding: 14px 48px;
            font-size: 12px;
            color: #374151;
        }

        .footer-line {
            display: flex;
            justify-content: space-between;
        }

        .payment-box {
            border: 1px dashed #cbd5f5;
            padding: 12px 15px;
            background: #f8fafc;
            font-size: 11px;
            margin-top: 20px;
        }
    </style>
</head>

<body>

    <!-- HEADER -->
    <div class="header">
        <h1>WireDevelop</h1>
        <p>Soluções Digitais & Desenvolvimento Web</p>
    </div>

    <!-- CONTENT -->
    <div class="container">

        <h2>{{ $product->name }}</h2>

        @if($product->short_description)
            <p class="subtitle">{{ $product->short_description }}</p>
        @endif

        @if($product->type === 'product' && !is_null($product->price))
            <p class="product-price">{{ number_format((float) $product->price, 2, ',', '.') }} €</p>
        @endif

        @if(!empty($product->content_html))
            @php
                $content = (string) $product->content_html;
                $emojiReplacements = [
                    '📝' => '[Nota] ',
                    '📚' => '[Conteudos] ',
                    '⚙️' => '[Tecnica] ',
                    '⚙' => '[Tecnica] ',
                    '🛒' => '[Funcionalidades] ',
                    '📈' => '[Marketing] ',
                    '🔒' => '[Seguranca] ',
                    '📞' => '[Suporte] ',
                    '⚠️' => '[Importante] ',
                    '⚠' => '[Importante] ',
                    '✅' => '[OK] ',
                    '✔️' => '[OK] ',
                    '✔' => '[OK] ',
                    '•' => '- ',
                ];
                $content = strtr($content, $emojiReplacements);
                $hasHtml = $content !== strip_tags($content);
            @endphp

            <div class="content-card {{ $hasHtml ? '' : 'plain-text' }}">
                @if($hasHtml)
                    {!! $content !!}
                @else
                    {{ $content }}
                @endif
            </div>
        @endif

        {{-- PACKS --}}
        @if($product->type === 'pack')
            @foreach($product->packItems as $item)
                <div class="pack-card {{ $item->featured ? 'featured' : '' }}">
                    @if($item->featured)
                        <div class="badge">MAIS VENDIDO</div>
                    @endif

                    <div class="pack-title">
                        {{ $item->hours }} horas
                    </div>

                    <table class="pack-details">
                        <tr>
                            <td class="label">Preço normal</td>
                            <td class="old-price">{{ number_format($item->normal_price, 2, ',', '.') }} €</td>
                        </tr>
                        <tr>
                            <td class="label">Preço pack</td>
                            <td class="price">{{ number_format($item->pack_price, 2, ',', '.') }} €</td>
                        </tr>
                        <tr>
                            <td class="label">Validade</td>
                            <td>{{ $item->validity_months }} meses</td>
                        </tr>
                    </table>
                </div>
            @endforeach
        @endif

        {{-- INFO FIELDS (NOVA PÁGINA) --}}
        @if($product->meta->count())
            <div class="info-section">
                <h3>Informação adicional</h3>

                @foreach($product->meta as $meta)
                    <div style="margin-bottom:14px;">
                        <strong>{{ $meta->label }}</strong><br>

                        @if($meta->type === 'html')
                            {!! $meta->value !!}
                        @else
                            {!! nl2br(e($meta->value)) !!}
                        @endif
                    </div>
                @endforeach
            </div>
        @endif

        @if(!empty($company) && $product->show_payment_methods)
            <div class="payment-box">
                <strong>Dados para pagamento</strong><br>
                @if(!empty($company['name'])) {{ $company['name'] }}<br> @endif
                @if(!empty($company['vat'])) NIF: {{ $company['vat'] }}<br> @endif
                @if(!empty($company['address'])) Morada: {{ $company['address'] }}<br> @endif
                @if(!empty($company['postal_code']) || !empty($company['city']))
                    {{ $company['postal_code'] ?? '' }} {{ $company['city'] ?? '' }}<br>
                @endif
                @if(!empty($company['country'])) {{ $company['country'] }}<br> @endif
                @if(!empty($company['email'])) Email: {{ $company['email'] }}<br> @endif
                @if(!empty($company['phone'])) Telefone: {{ $company['phone'] }}<br> @endif
                @if(!empty($company['website'])) {{ $company['website'] }}<br> @endif
                @if(!empty($company['iban'])) IBAN: {{ $company['iban'] }}<br> @endif
                @if(!empty($company['bank_name'])) Banco: {{ $company['bank_name'] }}<br> @endif
                @if(!empty($company['swift'])) SWIFT/BIC: {{ $company['swift'] }}<br> @endif
                @if(!empty($company['payment_methods']) && is_array($company['payment_methods']))
                    @foreach($company['payment_methods'] as $method)
                        @if(!empty($method['label']) || !empty($method['value']))
                            {{ $method['label'] ?? 'Metodo' }}: {{ $method['value'] ?? '' }}<br>
                        @endif
                    @endforeach
                @endif
                @if(!empty($company['payment_notes']))
                    <span class="label">{!! nl2br(e($company['payment_notes'])) !!}</span>
                @endif
            </div>
        @endif

    </div>

    <!-- FOOTER -->
    <div class="footer">
        <div class="footer-line">
            <div>WireDevelop</div>
            <div>geral@wiredevelop.pt | 963 286 319</div>
        </div>
    </div>

</body>

</html>
