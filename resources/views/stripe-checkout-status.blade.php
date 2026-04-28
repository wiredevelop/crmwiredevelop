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
    </style>
</head>
<body>
    <div class="card">
        <h1>{{ $title }}</h1>
        <p>{{ $message }}</p>
    </div>
</body>
</html>
