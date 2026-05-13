<!DOCTYPE html>
<html lang="pt">
<head>
    <meta charset="UTF-8">
    <title>{{ $subjectLine }}</title>
</head>
<body style="font-family: Arial, sans-serif; color: #1f2937; line-height: 1.5;">
    <h2 style="color: #015557;">{{ $subjectLine }}</h2>
    <p>Olá {{ $client->name }},</p>
    {!! nl2br(e($messageBody)) !!}
</body>
</html>
