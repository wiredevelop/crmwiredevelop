<!DOCTYPE html>
<html lang="pt">

<head>
    <meta charset="UTF-8">
    <title>Orçamento – {{ $project->name }}</title>

    <style>
        /* ================= PAGE ================= */
        @page {
            margin-top: 10px;
            margin-bottom: 10px;
            margin-left: 0;
            margin-right: 0;
        }

        body {
            font-family: DejaVu Sans, Helvetica, Arial, sans-serif;
            font-size: 12px;
            margin: 0;
            padding: 0;
            color: #1f2937;
            background: #ffffff;
        }

        /* ================= HEADER ================= */
        .header {
            background: #015557;
            color: #ffffff;
            padding: 28px 48px;
        }

        .brand {
            font-size: 22px;
            font-weight: 800;
        }

        .tagline {
            margin-top: 6px;
            font-size: 12px;
            opacity: .95;
        }

        /* ================= CONTENT ================= */
        .container {
            padding: 36px 48px 120px 48px;
            /* espaço real para footer */
        }

        .section-title {
            font-size: 16px;
            font-weight: 800;
            color: #015557;
            margin: 22px 0 12px;
        }

        .card {
            border: 1px solid #e5e7eb;
            border-radius: 10px;
            padding: 14px 16px;
            margin-bottom: 12px;
        }

        .muted {
            color: #6b7280;
        }

        /* ================= TABLES ================= */
        table {
            width: 100%;
            border-collapse: collapse;
            font-size: 12px;
        }

        th,
        td {
            border: 1px solid #e5e7eb;
            padding: 8px 10px;
        }

        th {
            background: #f9fafb;
            text-align: left;
        }

        .right {
            text-align: right;
        }

        /* ================= PACKS ================= */
        .pack-wrapper {
            margin-bottom: 18px;
        }

        .pack-card {
            border: 1px solid #e5e7eb;
            border-left: 6px solid #015557;
            border-radius: 10px;
            padding: 16px 18px;
            margin-bottom: 12px;
            position: relative;
        }

        .pack-card.featured {
            border-left-color: #0f766e;
            background: #f0fdfa;
        }

        .badge {
            position: absolute;
            top: -10px;
            right: 14px;
            background: #015557;
            color: #ffffff;
            font-size: 10px;
            padding: 6px 10px;
            border-radius: 999px;
        }

        .pack-title {
            font-size: 14px;
            font-weight: 800;
            margin-bottom: 10px;
        }

        .pack-details td {
            border: 0;
            padding: 4px 0;
        }

        .old-price {
            text-decoration: line-through;
            color: #9ca3af;
        }

        .price {
            font-size: 16px;
            font-weight: 900;
            color: #015557;
        }

        /* ================= FOOTER ================= */
        .footer {
            position: fixed;
            bottom: 0;
            width: 100%;
            background: #f9fafb;
            padding: 14px 48px;
            font-size: 11px;
            color: #374151;
        }

        .footer-line {
            display: flex;
            justify-content: space-between;
        }

        .description-content {
            line-height: 1.35;
        }

        .description-content p {
            margin: 4px 0;
        }

        .description-content h1,
        .description-content h2,
        .description-content h3,
        .description-content h4,
        .description-content h5,
        .description-content h6 {
            margin: 6px 0 4px;
        }

        .description-content ul,
        .description-content ol {
            margin: 6px 0 6px 18px;
            padding: 0;
        }

        .description-content li {
            margin: 2px 0;
        }

        .payment-box {
            border: 1px dashed #cbd5f5;
            padding: 12px 15px;
            background: #f8fafc;
            font-size: 11px;
            margin-bottom: 24px;
        }
    </style>
</head>

<body>

    <!-- HEADER -->
    <div class="header">
        <div class="brand">WireDevelop</div>
        <div class="tagline">Soluções Digitais & Desenvolvimento Web</div>
    </div>

    <div class="container">

        <!-- INFO -->
        <div class="card">
            <div><strong>Projeto:</strong> {{ $project->name }}</div>
            <div>
                <strong>Cliente:</strong>
                {{ $client->name }}
                @if($client->company) — {{ $client->company }} @endif
            </div>
            <div class="muted" style="margin-top:6px;">
                <strong>Tipo:</strong> {{ $quote->project_type }}
                @if($quote->technologies)
                    · <strong>Tecnologias:</strong> {{ $quote->technologies }}
                @endif
            </div>
        </div>

        @if($quote->description)
            @php
                $desc = $quote->description ?? '';
                $isHtml = preg_match('/<\\s*[\\w-]+[^>]*>/', $desc);
            @endphp
            <div class="section-title">Descrição</div>
            <div class="card description-content">
                @if($isHtml)
                    {!! $desc !!}
                @else
                    {!! nl2br(e($desc)) !!}
                @endif
            </div>
        @endif

        <!-- DESENVOLVIMENTO -->
        <div class="section-title">Plano de Desenvolvimento</div>
        <table>
            <thead>
                <tr>
                    <th>Funcionalidade</th>
                    <th class="right">Horas</th>
                </tr>
            </thead>
            <tbody>
                @foreach ($quote->development_items as $item)
                    <tr>
                        <td>{{ $item['feature'] }}</td>
                        <td class="right">{{ $item['hours'] }}</td>
                    </tr>
                @endforeach
            </tbody>
            <tfoot>
                <tr>
                    <th class="right">Total de horas</th>
                    <th class="right">{{ $quote->development_total_hours }}</th>
                </tr>
            </tfoot>
        </table>

        <!-- VALORES -->
        @php
            $dev = (float) ($quote->price_development ?? 0);
            $packs = (float) ($quote->products_total ?? 0);

            // DOMÍNIO
            $domainFirstYear = ($quote->include_domain ?? false)
                ? (float) ($quote->price_domain_first_year ?? 0)
                : 0;

            $domainOtherYears = ($quote->include_domain ?? false)
                ? (float) ($quote->price_domain_other_years ?? 0)
                : 0;

            // ALOJAMENTO
            $hostingFirstYear = ($quote->include_hosting ?? false)
                ? (float) ($quote->price_hosting_first_year ?? 0)
                : 0;

            $hostingOtherYears = ($quote->include_hosting ?? false)
                ? (float) ($quote->price_hosting_other_years ?? 0)
                : 0;

            $maintMonthly = (float) ($quote->price_maintenance_monthly ?? 0);
            $maintFixed = (float) ($quote->price_maintenance_fixed ?? 0);

            // TOTAL INICIAL (1º ano)
            $baseTotal = $dev + $packs + $domainFirstYear + $hostingFirstYear;
        @endphp

        <div class="section-title">Valores</div>

        <table>
            <tbody>
                <tr>
                    <td>Desenvolvimento</td>
                    <td class="right">{{ number_format($dev, 2, ',', '.') }} €</td>
                </tr>

                @if($packs > 0)
                    <tr>
                        <td>Produtos / Packs</td>
                        <td class="right">{{ number_format($packs, 2, ',', '.') }} €</td>
                    </tr>
                @endif

                @if($quote->include_domain)
                    <tr>
                        <td>Domínio (1º ano)</td>
                        <td class="right">{{ number_format($domainFirstYear, 2, ',', '.') }} €</td>
                    </tr>
                    <tr>
                        <td class="muted">Domínio (anos seguintes)</td>
                        <td class="right muted">{{ number_format($domainOtherYears, 2, ',', '.') }} €</td>
                    </tr>
                @endif

                @if($quote->include_hosting)
                    <tr>
                        <td>Alojamento (1º ano)</td>
                        <td class="right">{{ number_format($hostingFirstYear, 2, ',', '.') }} €</td>
                    </tr>
                    <tr>
                        <td class="muted">Alojamento (anos seguintes)</td>
                        <td class="right muted">{{ number_format($hostingOtherYears, 2, ',', '.') }} €</td>
                    </tr>
                @endif

                @if($maintFixed > 0)
                    <tr>
                        <td>Manutenção fixa</td>
                        <td class="right">{{ number_format($maintFixed, 2, ',', '.') }} €</td>
                    </tr>
                @endif

                @if($maintMonthly > 0)
                    <tr>
                        <td>Manutenção mensal <span class="muted">(opcional)</span></td>
                        <td class="right">{{ number_format($maintMonthly, 2, ',', '.') }} €</td>
                    </tr>
                @endif
            </tbody>

            <tfoot>
                <tr>
                    <th>Total</th>
                    <th class="right">{{ number_format($baseTotal, 2, ',', '.') }} €</th>
                </tr>
            </tfoot>
        </table>

        @if($quote->terms)
            <div class="section-title">Prazos & Condições</div>
            <div class="card">{!! nl2br(e($quote->terms)) !!}</div>
        @endif

        <!-- PACKS / UPSELL -->
        @if($quote->quoteProducts && $quote->quoteProducts->count())
            <div class="section-title">Produtos / Packs Recomendados</div>

            @foreach($quote->quoteProducts as $qp)
                <div class="pack-wrapper">
                    <div class="card">
                        <strong>{{ $qp->name }}</strong>
                        <span class="muted">({{ strtoupper($qp->type) }})</span>

                        @if($qp->type === 'pack')
                            <div style="margin-top:12px;">
                                @foreach($qp->pack_items as $item)
                                    <div class="pack-card {{ $item['featured'] ? 'featured' : '' }}">
                                        @if($item['featured'])
                                            <div class="badge">MAIS VENDIDO</div>
                                        @endif

                                        <div class="pack-title">{{ $item['hours'] }} horas</div>

                                        <table class="pack-details">
                                            <tr>
                                                <td class="muted">Preço normal</td>
                                                <td class="old-price right">
                                                    {{ number_format($item['normal_price'], 2, ',', '.') }} €
                                                </td>
                                            </tr>
                                            <tr>
                                                <td class="muted">Preço pack</td>
                                                <td class="price right">
                                                    {{ number_format($item['pack_price'], 2, ',', '.') }} €
                                                </td>
                                            </tr>
                                            <tr>
                                                <td class="muted">Validade</td>
                                                <td class="right">{{ $item['validity_months'] }} meses</td>
                                            </tr>
                                        </table>
                                    </div>
                                @endforeach
                            </div>
                        @endif

                        @if(is_array($qp->info_fields) && count($qp->info_fields))
                            <div style="margin-top:14px;">
                                <strong style="color:#015557;">Informação adicional</strong>

                                @foreach($qp->info_fields as $field)
                                    <div style="margin-top:6px;">
                                        <strong>{{ $field['label'] ?? '' }}</strong><br>
                                        {!! nl2br(e($field['value'] ?? '')) !!}
                                    </div>
                                @endforeach
                            </div>
                        @endif
                    </div>
                </div>
            @endforeach
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
