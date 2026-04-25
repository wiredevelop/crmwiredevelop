<?php

namespace App\Http\Controllers\WebAuthn;

use Illuminate\Contracts\Support\Responsable;
use Illuminate\Http\Response;
use Laragear\WebAuthn\Http\Requests\AssertionRequest;
use Laragear\WebAuthn\Http\Requests\AssertedRequest;

class PasskeyLoginController
{
    /**
     * Returns the challenge for WebAuthn assertion.
     */
    public function options(AssertionRequest $request): Responsable
    {
        return $request->toVerify(
            $request->validate(['email' => 'sometimes|string|email'])
        );
    }

    /**
     * Validate the passkey and login the user.
     */
    public function login(AssertedRequest $request): Response
    {
        // Tenta login via WebAuthn (isto já cria a sessão do utilizador)
        $ok = $request->login();

        if (! $ok) {
            return response('', 422); // erro de autenticação
        }

        // Redireciona após login válido
        return response()->noContent(204);
    }
}
