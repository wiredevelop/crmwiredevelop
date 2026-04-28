<!DOCTYPE html>
<html lang="pt">

<head>
    <meta charset="UTF-8">
    <title>Recibo {{ $invoice->number }}</title>

    <style>
        body {
            font-family: DejaVu Sans, sans-serif;
            font-size: 12px;
            margin: 0;
            padding: 40px;
            color: #333;
        }

        .header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 35px;
        }

        .logo h1 {
            width: 160px;
            color: #015557;
        }

        .ribbon {
            position: absolute;
            top: 40px;
            right: -55px;
            transform: rotate(45deg);
            width: 240px;
            text-align: center;
            padding: 10px 0;
            color: #fff;
            font-weight: bold;
        }

        .ribbon-pago {
            background: #27ae60;
        }

        .ribbon-pendente {
            background: #c0392b;
        }

        .box {
            border: 1px solid #ccc;
            padding: 12px 15px;
            margin-bottom: 20px;
        }

        .title {
            font-weight: bold;
            margin-bottom: 5px;
        }

        table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 15px;
        }

        th {
            background: #f2f2f2;
            text-align: left;
            padding: 10px;
            border: 1px solid #ddd;
        }

        td {
            padding: 10px;
            border: 1px solid #ddd;
        }

        .text-right {
            text-align: right;
        }

        .totals {
            margin-top: 25px;
            width: 100%;
        }

        .totals td {
            padding: 6px;
            border: none;
        }

        .totals .label {
            font-weight: bold;
        }

        .footer {
            margin-top: 40px;
            font-size: 11px;
            text-align: center;
            color: #666;
        }

        .payment-box {
            margin-top: 25px;
            border: 1px dashed #cbd5f5;
            padding: 12px 15px;
            font-size: 11px;
            background: #f8fafc;
        }

        .payment-method {
            margin-top: 6px;
            padding-top: 6px;
            border-top: 1px dashed #d1d5db;
        }

        .payment-method:first-child {
            margin-top: 0;
            padding-top: 0;
            border-top: 0;
        }

        .payment-label {
            font-weight: bold;
        }

        .note {
            font-size: 10px;
            color: #6b7280;
            margin-top: 6px;
        }
    </style>

</head>

<body>

    <!-- Ribbon -->
    <div class="ribbon {{ $invoice->status === 'pago' ? 'ribbon-pago' : 'ribbon-pendente' }}">
        {{ strtoupper($invoice->status) }}
    </div>

    <!-- Header -->
    <div class="header">
        <div class="logo">
            <h1>WIREDEVELOP</h1>
        </div>

        <div>
            <strong>Recibo:</strong> {{ $invoice->number }}<br>
            <strong>Data:</strong> {{ optional($invoice->issued_at)->format('d/m/Y') }}<br>
            <strong>Vencimento:</strong> {{ optional($invoice->due_at)->format('d/m/Y') }}<br>
            @if($invoice->paid_at)
                <strong>Pago em:</strong> {{ optional($invoice->paid_at)->format('d/m/Y') }}
            @endif
            <div class="note">Este documento nao serve como fatura. Serve como recibo.</div>
        </div>
    </div>

    @php
        $invoiceDescription = 'Servico';

        if ($invoice->project) {
            $invoiceDescription = $invoice->project->name . ' (' . $invoice->project->type . ')';
        } elseif ($invoice->walletTransactions && $invoice->walletTransactions->count()) {
            $tx = $invoice->walletTransactions->first();
            $invoiceDescription = $tx->description
                ?? ($tx->product?->name ? $tx->product->name : 'Venda de pack/produto');

            if ($tx->packItem?->hours) {
                $invoiceDescription .= ' - ' . $tx->packItem->hours . 'h';
            }
        }

        $items = $invoice->items ?? collect();
        $transactionsById = $invoice->walletTransactions
            ? $invoice->walletTransactions->keyBy('id')
            : collect();
    @endphp

    <!-- Cliente -->
    <div class="box">
        <div class="title">Cliente</div>

        Representante: {{ $invoice->client->name }}<br>

        @if($invoice->client->company)
            Empresa: {{ $invoice->client->company }}<br>
        @endif

        @if($invoice->client->email)
            Email: {{ $invoice->client->email }}<br>
        @endif

        @if($invoice->client->phone)
            Telefone: {{ $invoice->client->phone }}<br>
        @endif
    </div>

    <!-- Tabela Financeira -->
    <table>
        <thead>
            <tr>
                <th>Descrição</th>
                <th class="text-right">Qtd</th>
                <th class="text-right">Preço</th>
                <th class="text-right">Total (€)</th>
            </tr>
        </thead>

        <tbody>
            @if($items->count())
                @foreach($items as $item)
                    @php
                        $description = $item->description;
                        $quantity = (float) $item->quantity;

                        if (($item->source_type ?? null) === 'transaction') {
                            $tx = $transactionsById->get($item->source_id);

                            if ($tx && $tx->intervention) {
                                $notes = trim((string) ($tx->intervention->notes ?? ''));
                                $finishNotes = trim((string) ($tx->intervention->finish_notes ?? ''));
                                $totalSeconds = (int) ($tx->intervention->total_seconds ?? 0);
                                if ($totalSeconds > 0) {
                                    $quantity = $totalSeconds / 3600;
                                }
                                if ($notes !== '') {
                                    $description .= "\nNotas: " . $notes;
                                }

                                if ($finishNotes !== '') {
                                    $description .= "\nNotas fim: " . $finishNotes;
                                }
                            }
                        }
                    @endphp
                    <tr>
                        <td>{!! nl2br(e($description)) !!}</td>
                        <td class="text-right">{{ number_format($quantity, 2, ',', '.') }}</td>
                        <td class="text-right">{{ number_format((float) $item->unit_price, 2, ',', '.') }}</td>
                        <td class="text-right">{{ number_format((float) $item->total, 2, ',', '.') }}</td>
                    </tr>
                @endforeach
            @else
                <tr>
                    <td>{{ $invoiceDescription }}</td>
                    <td class="text-right">1,00</td>
                    <td class="text-right">{{ number_format($invoice->total, 2, ',', '.') }}</td>
                    <td class="text-right">{{ number_format($invoice->total, 2, ',', '.') }}</td>
                </tr>
            @endif

        </tbody>

        <tfoot>
            <tr>
                <th colspan="3">Total</th>
                <th class="text-right">{{ number_format($invoice->total, 2, ',', '.') }} €</th>
            </tr>
        </tfoot>
    </table>

    @if(!empty($company))
        <div class="payment-box">
            <strong>Dados para pagamento</strong><br>
            @if(!empty($company['iban'])) IBAN: {{ $company['iban'] }}<br> @endif
            @if(!empty($company['bank_name'])) Banco: {{ $company['bank_name'] }}<br> @endif
            @if(!empty($company['swift'])) SWIFT/BIC: {{ $company['swift'] }}<br> @endif
            @if(!empty($company['payment_notes']))
                <span class="note">{!! nl2br(e($company['payment_notes'])) !!}</span>
            @endif
            @if(!empty($company['payment_methods']) && is_array($company['payment_methods']))
                <div style="margin-top:8px;">
                    @foreach($company['payment_methods'] as $method)
                        @if(!empty($method['label']) || !empty($method['value']))
                            <div class="payment-method">
                                <div class="payment-label">{{ $method['label'] ?? 'Metodo' }}</div>
                                <div>{{ $method['value'] ?? '' }}</div>
                            </div>
                        @endif
                    @endforeach
                </div>
            @endif
        </div>
    @endif

    <div class="footer">
        WireDevelop — Soluções Digitais & Desenvolvimento Web<br>
        www.wiredevelop.pt — geral@wiredevelop.pt
    </div>

</body>

</html>
