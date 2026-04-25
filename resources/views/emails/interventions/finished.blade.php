<!DOCTYPE html>
<html lang="pt">
<head>
    <meta charset="utf-8">
    <title>Intervencao concluida</title>
</head>
<body style="font-family: Arial, sans-serif; color: #111827;">
    <h2 style="margin: 0 0 12px;">Intervencao concluida</h2>

    <p style="margin: 0 0 12px;">A intervencao foi concluida com sucesso.</p>

    <table style="width: 100%; border-collapse: collapse;">
        <tr>
            <td style="padding: 6px 0; font-weight: bold;">Cliente</td>
            <td style="padding: 6px 0;">{{ $intervention->client?->name ?? '—' }}
                @if($intervention->client?->company)
                    ({{ $intervention->client->company }})
                @endif
            </td>
        </tr>
        <tr>
            <td style="padding: 6px 0; font-weight: bold;">Tipo</td>
            <td style="padding: 6px 0;">{{ $intervention->type }}</td>
        </tr>
        <tr>
            <td style="padding: 6px 0; font-weight: bold;">Inicio</td>
            <td style="padding: 6px 0;">{{ optional($intervention->started_at)->format('d/m/Y H:i:s') ?? '—' }}</td>
        </tr>
        <tr>
            <td style="padding: 6px 0; font-weight: bold;">Fim</td>
            <td style="padding: 6px 0;">{{ optional($intervention->ended_at)->format('d/m/Y H:i:s') ?? '—' }}</td>
        </tr>
        <tr>
            <td style="padding: 6px 0; font-weight: bold;">Duracao</td>
            <td style="padding: 6px 0;">{{ $duration }}</td>
        </tr>
        @if($intervention->notes)
        <tr>
            <td style="padding: 6px 0; font-weight: bold;">Notas inicio</td>
            <td style="padding: 6px 0;">{{ $intervention->notes }}</td>
        </tr>
        @endif
        @if($intervention->finish_notes)
        <tr>
            <td style="padding: 6px 0; font-weight: bold;">Notas fim</td>
            <td style="padding: 6px 0;">{{ $intervention->finish_notes }}</td>
        </tr>
        @endif
    </table>
</body>
</html>
