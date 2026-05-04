<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;
use Symfony\Component\HttpFoundation\Response;
use Throwable;

class LogApiRequests
{
    public function handle(Request $request, Closure $next): Response
    {
        $requestId = $request->header('X-Request-Id') ?: (string) Str::uuid();
        $request->attributes->set('request_id', $requestId);

        $startedAt = microtime(true);
        $baseContext = $this->baseContext($request, $requestId);
        $isLoginAttempt = $request->is('api/v1/auth/login');

        if ($isLoginAttempt) {
            Log::info('API request started.', array_merge($baseContext, [
                'payload' => $this->sanitizedPayload($request),
            ]));
        }

        try {
            $response = $next($request);
        } catch (Throwable $error) {
            Log::error('API request crashed.', array_merge($baseContext, [
                'duration_ms' => $this->durationMs($startedAt),
                'payload' => $this->sanitizedPayload($request),
                'exception' => $error::class,
                'exception_message' => $error->getMessage(),
            ]));

            throw $error;
        }

        $response->headers->set('X-Request-Id', $requestId);

        if ($isLoginAttempt || $response->getStatusCode() >= 400) {
            Log::info('API request finished.', array_merge($baseContext, [
                'duration_ms' => $this->durationMs($startedAt),
                'status' => $response->getStatusCode(),
                'user_id' => $request->user()?->id,
                'payload' => $this->sanitizedPayload($request),
                'response_preview' => $this->responsePreview($response),
            ]));
        }

        return $response;
    }

    private function baseContext(Request $request, string $requestId): array
    {
        return [
            'request_id' => $requestId,
            'method' => $request->getMethod(),
            'host' => $request->getHost(),
            'path' => $request->path(),
            'ip' => $request->ip(),
            'forwarded_for' => $request->header('X-Forwarded-For'),
            'forwarded_proto' => $request->header('X-Forwarded-Proto'),
            'user_agent' => $request->userAgent(),
            'content_type' => $request->header('Content-Type'),
            'accept' => $request->header('Accept'),
        ];
    }

    private function sanitizedPayload(Request $request): array
    {
        return collect($request->all())
            ->map(function ($value, string $key) {
                $normalizedKey = Str::lower($key);

                if (Str::contains($normalizedKey, [
                    'password',
                    'token',
                    'secret',
                    'authorization',
                ])) {
                    return '[REDACTED]';
                }

                return is_scalar($value) || $value === null ? $value : '[COMPLEX]';
            })
            ->all();
    }

    private function responsePreview(Response $response): ?string
    {
        $content = $response->getContent();

        if (! is_string($content) || $content === '') {
            return null;
        }

        return Str::limit(preg_replace('/\s+/', ' ', $content) ?? $content, 300);
    }

    private function durationMs(float $startedAt): int
    {
        return (int) round((microtime(true) - $startedAt) * 1000);
    }
}
