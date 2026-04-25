<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Api\Concerns\RespondsWithJson;
use App\Http\Controllers\Controller;
use App\Http\Requests\Auth\LoginRequest;
use App\Http\Resources\Api\UserResource;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Validation\ValidationException;

class AuthController extends Controller
{
    use RespondsWithJson;

    public function login(LoginRequest $request): JsonResponse
    {
        $data = $request->validate([
            'email' => ['required', 'email'],
            'password' => ['required', 'string'],
            'device_name' => ['nullable', 'string', 'max:255'],
        ]);

        $request->ensureIsNotRateLimited();

        if (! Auth::validate($request->only('email', 'password'))) {
            RateLimiter::hit($request->throttleKey());

            Log::warning('API login failed.', [
                'email' => $data['email'],
                'ip' => $request->ip(),
                'host' => $request->getHost(),
                'path' => $request->path(),
                'user_agent' => $request->userAgent(),
                'reason' => 'invalid_credentials',
            ]);

            throw ValidationException::withMessages([
                'email' => [trans('auth.failed')],
            ]);
        }

        RateLimiter::clear($request->throttleKey());

        $user = User::where('email', $data['email'])->firstOrFail();
        $token = $user->createToken($data['device_name'] ?? 'flutter-app')->plainTextToken;

        Log::info('API login succeeded.', [
            'user_id' => $user->id,
            'email' => $user->email,
            'ip' => $request->ip(),
            'host' => $request->getHost(),
            'path' => $request->path(),
            'device_name' => $data['device_name'] ?? 'flutter-app',
        ]);

        return $this->success([
            'token' => $token,
            'token_type' => 'Bearer',
            'user' => new UserResource($user),
        ], 'Sessão iniciada com sucesso.');
    }

    public function me(Request $request): JsonResponse
    {
        return $this->success([
            'user' => new UserResource($request->user()),
        ]);
    }

    public function logout(Request $request): JsonResponse
    {
        $request->user()->currentAccessToken()?->delete();

        return $this->success([], 'Sessão terminada com sucesso.');
    }
}
