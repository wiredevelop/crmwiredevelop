<!DOCTYPE html>
<html lang="pt">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>{{ $title }}</title>
    <style>
        body {
            margin: 0;
            font-family: Arial, sans-serif;
            background: linear-gradient(160deg, #015557 0%, #0d7473 100%);
            color: #0e4d50;
            min-height: 100vh;
            display: grid;
            place-items: center;
            padding: 24px;
        }
        .card {
            width: min(520px, 100%);
            background: rgba(255, 255, 255, 0.88);
            border-radius: 22px;
            padding: 28px;
            box-shadow: 0 18px 48px rgba(0, 0, 0, 0.14);
        }
        h1 {
            margin: 0 0 12px;
        }
        p {
            margin: 0;
            line-height: 1.5;
        }
        .actions {
            display: flex;
            flex-wrap: wrap;
            gap: 12px;
            margin-top: 20px;
        }
        .button {
            appearance: none;
            border: 0;
            border-radius: 14px;
            cursor: pointer;
            display: inline-flex;
            align-items: center;
            justify-content: center;
            font: inherit;
            font-weight: 700;
            padding: 12px 18px;
            text-decoration: none;
            transition: transform 120ms ease, opacity 120ms ease;
        }
        .button:hover {
            transform: translateY(-1px);
        }
        .button-primary {
            background: #015557;
            color: #fff;
        }
        .button-secondary {
            background: #e7f0ef;
            color: #0e4d50;
        }
        .hint {
            color: rgba(14, 77, 80, 0.75);
            font-size: 14px;
            margin-top: 14px;
        }
    </style>
</head>
<body>
    <div class="card">
        <h1>{{ $title }}</h1>
        <p>{{ $message }}</p>
        <div class="actions">
            @if ($appUrl)
                <a class="button button-primary" href="{{ $appUrl }}" id="open-app">Abrir app</a>
            @endif
            @if ($fallbackUrl)
                <a class="button button-secondary" href="{{ $fallbackUrl }}">Abrir carteira na web</a>
            @endif
        </div>
        <p class="hint" id="status-hint">
            @if ($appUrl)
                A tentar regressar automaticamente à aplicação.
            @elseif ($fallbackUrl)
                A carteira pode ser reaberta diretamente na web.
            @else
                Se a app estiver instalada, pode voltar manualmente para confirmar o estado.
            @endif
        </p>
    </div>
    @if ($appUrl || $fallbackUrl)
        <script>
            (function () {
                const appUrl = @json($appUrl);
                const fallbackUrl = @json($fallbackUrl);
                const isMobileFlow = @json(($appUrl ?? null) !== null);
                const hint = document.getElementById('status-hint');
                const appButton = document.getElementById('open-app');
                let fallbackTimer = null;
                let appOpened = false;
                const isAndroid = /Android/i.test(window.navigator.userAgent || '');

                const resolveAppUrl = () => {
                    if (!appUrl) {
                        return appUrl;
                    }

                    if (!isAndroid || !appUrl.startsWith('wirecrm://')) {
                        return appUrl;
                    }

                    const raw = appUrl.replace('wirecrm://', '');
                    return `intent://${raw}#Intent;scheme=wirecrm;package=app.wiredevelop.pt;end`;
                };

                const launchUrl = resolveAppUrl();

                if (appButton && launchUrl) {
                    appButton.setAttribute('href', launchUrl);
                }

                const redirectToFallback = () => {
                    if (!fallbackUrl || appOpened) {
                        return;
                    }
                    window.location.replace(fallbackUrl);
                };

                const openApp = () => {
                    if (!isMobileFlow || !launchUrl) {
                        return;
                    }

                    fallbackTimer = window.setTimeout(() => {
                        if (!appOpened) {
                            redirectToFallback();
                        }
                    }, fallbackUrl ? 1800 : 0);

                    window.location.href = launchUrl;
                };

                document.addEventListener('visibilitychange', () => {
                    if (document.visibilityState === 'hidden') {
                        appOpened = true;
                        if (fallbackTimer) {
                            window.clearTimeout(fallbackTimer);
                        }
                    }
                });

                window.addEventListener('pagehide', () => {
                    appOpened = true;
                    if (fallbackTimer) {
                        window.clearTimeout(fallbackTimer);
                    }
                });

                if (isMobileFlow) {
                    openApp();
                } else if (fallbackUrl) {
                    if (hint) {
                        hint.textContent = 'A redirecionar para a carteira.';
                    }
                    window.setTimeout(() => redirectToFallback(), 300);
                }
            })();
        </script>
    @endif
</body>
</html>
