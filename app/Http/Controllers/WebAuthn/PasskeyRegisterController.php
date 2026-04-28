<?php

namespace App\Http\Controllers\WebAuthn;

use Illuminate\Contracts\Support\Responsable;
use Illuminate\Http\Response;
use Laragear\WebAuthn\Http\Requests\AttestationRequest;
use Laragear\WebAuthn\Http\Requests\AttestedRequest;

use function response;

class PasskeyRegisterController
{
    /**
     * Gera o challenge.
     */
    public function options(AttestationRequest $request): Responsable
    {
        return $request
            ->secureRegistration()   // biometria obrigatória
            ->userless()             // login sem email
            ->toCreate();
    }

    /**
     * Regista o dispositivo/passkey no servidor.
     */
    public function register(AttestedRequest $request): Response
    {
        // Valida challenge, assinaturas, origin, RP-ID, etc.
        $request->save();

        // WebAuthn recomenda 204 noContent
        return response()->noContent();
    }
}
