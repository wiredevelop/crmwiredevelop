<h1>Orçamento - {{ $project->name }}</h1>

    <h2>Informação</h2>
    <p><strong>Projeto:</strong> {{ $project->name }}</p>
    <p>
        <strong>Cliente:</strong> {{ $client->name }}
        @if($client->company) - {{ $client->company }} @endif
    </p>
    <p>
        <strong>Tipo:</strong> {{ $quote->project_type }}
        @if($quote->technologies)
            - <strong>Tecnologias:</strong> {{ $quote->technologies }}
        @endif
    </p>

    @if($quote->description)
        <h2>Descrição</h2>
        <p>{!! nl2br(e($quote->description)) !!}</p>
    @endif

    <h2>Plano de Desenvolvimento</h2>
    <table border="1" cellspacing="0" cellpadding="4">
        <thead>
            <tr>
                <th>Funcionalidade</th>
                <th>Horas</th>
            </tr>
        </thead>
        <tbody>
            @foreach ($quote->development_items as $item)
                <tr>
                    <td>{{ $item['feature'] }}</td>
                    <td>{{ $item['hours'] }}</td>
                </tr>
            @endforeach
        </tbody>
        <tfoot>
            <tr>
                <th>Total de horas</th>
                <th>{{ $quote->development_total_hours }}</th>
            </tr>
        </tfoot>
    </table>

    @php
        $dev = (float) ($quote->price_development ?? 0);
        $packs = (float) ($quote->products_total ?? 0);
        $domainFirstYear = ($quote->include_domain ?? false)
            ? (float) ($quote->price_domain_first_year ?? 0)
            : 0;
        $domainOtherYears = ($quote->include_domain ?? false)
            ? (float) ($quote->price_domain_other_years ?? 0)
            : 0;
        $hostingFirstYear = ($quote->include_hosting ?? false)
            ? (float) ($quote->price_hosting_first_year ?? 0)
            : 0;
        $hostingOtherYears = ($quote->include_hosting ?? false)
            ? (float) ($quote->price_hosting_other_years ?? 0)
            : 0;
        $maintMonthly = (float) ($quote->price_maintenance_monthly ?? 0);
        $maintFixed = (float) ($quote->price_maintenance_fixed ?? 0);
        $baseTotal = $dev + $packs + $domainFirstYear + $hostingFirstYear;
    @endphp

    <h2>Valores</h2>
    <table border="1" cellspacing="0" cellpadding="4">
        <tbody>
            <tr>
                <td>Desenvolvimento</td>
                <td>{{ number_format($dev, 2, ',', '.') }} €</td>
            </tr>
            @if($packs > 0)
                <tr>
                    <td>Produtos / Packs</td>
                    <td>{{ number_format($packs, 2, ',', '.') }} €</td>
                </tr>
            @endif
            @if($quote->include_domain)
                <tr>
                    <td>Domínio (1º ano)</td>
                    <td>{{ number_format($domainFirstYear, 2, ',', '.') }} €</td>
                </tr>
                <tr>
                    <td>Domínio (anos seguintes)</td>
                    <td>{{ number_format($domainOtherYears, 2, ',', '.') }} €</td>
                </tr>
            @endif
            @if($quote->include_hosting)
                <tr>
                    <td>Alojamento (1º ano)</td>
                    <td>{{ number_format($hostingFirstYear, 2, ',', '.') }} €</td>
                </tr>
                <tr>
                    <td>Alojamento (anos seguintes)</td>
                    <td>{{ number_format($hostingOtherYears, 2, ',', '.') }} €</td>
                </tr>
            @endif
            @if($maintFixed > 0)
                <tr>
                    <td>Manutenção fixa</td>
                    <td>{{ number_format($maintFixed, 2, ',', '.') }} €</td>
                </tr>
            @endif
            @if($maintMonthly > 0)
                <tr>
                    <td>Manutenção mensal (opcional)</td>
                    <td>{{ number_format($maintMonthly, 2, ',', '.') }} €</td>
                </tr>
            @endif
        </tbody>
        <tfoot>
            <tr>
                <th>Total</th>
                <th>{{ number_format($baseTotal, 2, ',', '.') }} €</th>
            </tr>
        </tfoot>
    </table>

    @if($quote->terms)
        <h2>Prazos & Condições</h2>
        <p>{!! nl2br(e($quote->terms)) !!}</p>
    @endif

    @if($quote->quoteProducts && $quote->quoteProducts->count())
        <h2>Produtos / Packs Recomendados</h2>
        @foreach($quote->quoteProducts as $qp)
            <h3>{{ $qp->name }} ({{ strtoupper($qp->type) }})</h3>
            @if($qp->type === 'pack' && !empty($qp->pack_items))
                <table border="1" cellspacing="0" cellpadding="4">
                    <thead>
                        <tr>
                            <th>Horas</th>
                            <th>Preço normal</th>
                            <th>Preço pack</th>
                            <th>Validade</th>
                        </tr>
                    </thead>
                    <tbody>
                        @foreach($qp->pack_items as $item)
                            <tr>
                                <td>{{ $item['hours'] }}h</td>
                                <td>{{ number_format($item['normal_price'], 2, ',', '.') }} €</td>
                                <td>{{ number_format($item['pack_price'], 2, ',', '.') }} €</td>
                                <td>{{ $item['validity_months'] }} meses</td>
                            </tr>
                        @endforeach
                    </tbody>
                </table>
            @endif
            @if(is_array($qp->info_fields) && count($qp->info_fields))
                <p><strong>Informação adicional</strong></p>
                @foreach($qp->info_fields as $field)
                    <p><strong>{{ $field['label'] ?? '' }}:</strong> {{ $field['value'] ?? '' }}</p>
                @endforeach
            @endif
        @endforeach
    @endif

    @if(!empty($company))
        <h2>Dados para pagamento</h2>
        @if(!empty($company['email'])) <p>Email: {{ $company['email'] }}</p> @endif
        @if(!empty($company['phone'])) <p>Telefone: {{ $company['phone'] }}</p> @endif
        @if(!empty($company['website'])) <p>{{ $company['website'] }}</p> @endif
        @if(!empty($company['payment_methods']) && is_array($company['payment_methods']))
            <p><strong>Metodos:</strong></p>
            @foreach($company['payment_methods'] as $method)
                @if(!empty($method['label']) || !empty($method['value']))
                    <p>{{ $method['label'] ?? 'Metodo' }}: {{ $method['value'] ?? '' }}</p>
                @endif
            @endforeach
        @endif
        @if(!empty($company['payment_notes']))
            <p>{!! nl2br(e($company['payment_notes'])) !!}</p>
        @endif
        @if(!empty($company['iban'])) <p>IBAN: {{ $company['iban'] }}</p> @endif
        @if(!empty($company['bank_name'])) <p>Banco: {{ $company['bank_name'] }}</p> @endif
        @if(!empty($company['swift'])) <p>SWIFT/BIC: {{ $company['swift'] }}</p> @endif
    @endif
