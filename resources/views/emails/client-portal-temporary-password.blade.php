<!DOCTYPE html>
<html lang="pt">
<head>
    <meta charset="UTF-8">
    <title>Acesso temporário</title>
</head>
<body style="font-family: Arial, sans-serif; color: #1f2937; line-height: 1.5;">
    <h2 style="color: #015557;">Acesso temporário ao WireDevelop CRM</h2>
    <p>Olá {{ $client->name }},</p>
    <p>Foi gerada uma nova senha temporária para o teu acesso.</p>
    <p><strong>Email:</strong> {{ $user->email }}</p>
    <p><strong>Senha temporária:</strong> {{ $temporaryPassword }}</p>
    <p>Ao iniciar sessão, terás de alterar esta senha antes de continuar.</p>
</body>
</html>
