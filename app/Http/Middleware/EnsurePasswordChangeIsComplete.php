<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class EnsurePasswordChangeIsComplete
{
    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();

        if (! $user || ! $user->must_change_password) {
            return $next($request);
        }

        if ($request->expectsJson() || $request->is('api/*')) {
            return response()->json([
                'message' => 'É obrigatório alterar a senha temporária antes de continuar.',
                'errors' => [
                    'password' => ['É obrigatório alterar a senha temporária antes de continuar.'],
                ],
                'meta' => [
                    'requires_password_change' => true,
                ],
            ], 423);
        }

        return redirect()->route('password.force.edit');
    }
}
