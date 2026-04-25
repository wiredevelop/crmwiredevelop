<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Laravel\Sanctum\PersonalAccessToken;
use Symfony\Component\HttpFoundation\Response;

class AuthenticateDocumentToken
{
    public function handle(Request $request, Closure $next): Response
    {
        $token = (string) $request->query('access_token', '');
        if ($token === '') {
            return response()->json([
                'message' => 'Token de acesso em falta.',
            ], 401);
        }

        $accessToken = PersonalAccessToken::findToken($token);
        if (!$accessToken || !$accessToken->tokenable) {
            return response()->json([
                'message' => 'Token de acesso inválido.',
            ], 401);
        }

        Auth::setUser($accessToken->tokenable);
        $request->setUserResolver(fn () => $accessToken->tokenable);

        return $next($request);
    }
}
