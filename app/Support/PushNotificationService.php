<?php

namespace App\Support;

use App\Models\DeviceToken;
use App\Models\User;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class PushNotificationService
{
    public function isConfigured(): bool
    {
        $credentials = $this->credentials();

        return filled($credentials['project_id'] ?? null)
            && filled($credentials['client_email'] ?? null)
            && filled($credentials['private_key'] ?? null);
    }

    public function sendToUsers(iterable $users, string $title, string $body, array $data = []): void
    {
        if (! $this->isConfigured()) {
            return;
        }

        $userIds = collect($users)
            ->map(fn ($user) => $user instanceof User ? $user->id : $user)
            ->filter()
            ->unique()
            ->values();

        if ($userIds->isEmpty()) {
            return;
        }

        $tokens = DeviceToken::query()
            ->whereIn('user_id', $userIds)
            ->where('notifications_enabled', true)
            ->pluck('token')
            ->unique()
            ->values();

        if ($tokens->isEmpty()) {
            return;
        }

        $accessToken = $this->accessToken();
        if (! $accessToken) {
            return;
        }

        $payloadData = collect($data)
            ->filter(fn ($value) => $value !== null)
            ->mapWithKeys(fn ($value, $key) => [$key => is_scalar($value) ? (string) $value : json_encode($value)])
            ->all();

        foreach ($tokens as $token) {
            $response = Http::withToken($accessToken)
                ->acceptJson()
                ->post($this->messagesUrl(), [
                    'message' => [
                        'token' => $token,
                        'notification' => [
                            'title' => $title,
                            'body' => $body,
                        ],
                        'data' => $payloadData,
                        'android' => [
                            'priority' => 'high',
                            'notification' => [
                                'channel_id' => 'wire_crm_updates',
                                'sound' => 'default',
                            ],
                        ],
                        'apns' => [
                            'headers' => [
                                'apns-priority' => '10',
                            ],
                            'payload' => [
                                'aps' => [
                                    'sound' => 'default',
                                    'badge' => 1,
                                ],
                            ],
                        ],
                    ],
                ]);

            if ($response->successful()) {
                continue;
            }

            $errorCode = data_get($response->json(), 'error.details.0.errorCode')
                ?? data_get($response->json(), 'error.status');

            if (in_array($errorCode, ['UNREGISTERED', 'INVALID_ARGUMENT', 'NOT_FOUND'], true)) {
                DeviceToken::query()->where('token', $token)->delete();
                continue;
            }

            Log::warning('Push notification send failed.', [
                'status' => $response->status(),
                'error' => $response->json(),
            ]);
        }
    }

    public function usersForClientStakeholders(?int $clientId, ?int $excludingUserId = null): Collection
    {
        if (! $clientId) {
            return $this->usersForAdmins($excludingUserId);
        }

        return User::query()
            ->where(function ($query) use ($clientId) {
                $query
                    ->where('role', User::ROLE_ADMIN)
                    ->orWhere('client_id', $clientId);
            })
            ->when($excludingUserId, fn ($query) => $query->whereKeyNot($excludingUserId))
            ->get();
    }

    public function usersForAdmins(?int $excludingUserId = null): Collection
    {
        return User::query()
            ->where('role', User::ROLE_ADMIN)
            ->when($excludingUserId, fn ($query) => $query->whereKeyNot($excludingUserId))
            ->get();
    }

    private function messagesUrl(): string
    {
        return sprintf(
            'https://fcm.googleapis.com/v1/projects/%s/messages:send',
            $this->credentials()['project_id'],
        );
    }

    private function accessToken(): ?string
    {
        return Cache::remember('firebase.messaging.access_token', now()->addMinutes(50), function () {
            $credentials = $this->credentials();
            if (! $this->isConfigured()) {
                return null;
            }

            $jwt = $this->buildJwt($credentials['client_email'], $credentials['private_key']);

            $response = Http::asForm()->post('https://oauth2.googleapis.com/token', [
                'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
                'assertion' => $jwt,
            ]);

            if (! $response->successful()) {
                Log::warning('Failed to fetch Firebase access token.', [
                    'status' => $response->status(),
                    'error' => $response->json(),
                ]);

                return null;
            }

            return $response->json('access_token');
        });
    }

    private function buildJwt(string $clientEmail, string $privateKey): string
    {
        $header = $this->base64UrlEncode(json_encode([
            'alg' => 'RS256',
            'typ' => 'JWT',
        ]));

        $now = now()->timestamp;

        $claims = $this->base64UrlEncode(json_encode([
            'iss' => $clientEmail,
            'scope' => 'https://www.googleapis.com/auth/firebase.messaging',
            'aud' => 'https://oauth2.googleapis.com/token',
            'iat' => $now,
            'exp' => $now + 3600,
        ]));

        $unsignedToken = $header.'.'.$claims;
        $signature = '';

        openssl_sign($unsignedToken, $signature, $privateKey, OPENSSL_ALGO_SHA256);

        return $unsignedToken.'.'.$this->base64UrlEncode($signature);
    }

    private function base64UrlEncode(string $value): string
    {
        return rtrim(strtr(base64_encode($value), '+/', '-_'), '=');
    }

    private function credentials(): array
    {
        $raw = config('services.firebase.service_account_json');

        if (is_string($raw) && $raw !== '') {
            if (is_file($raw)) {
                $decoded = json_decode((string) file_get_contents($raw), true);
                if (is_array($decoded)) {
                    return $this->normalizeCredentials($decoded);
                }
            }

            $decoded = json_decode($raw, true);
            if (is_array($decoded)) {
                return $this->normalizeCredentials($decoded);
            }
        }

        return $this->normalizeCredentials([
            'project_id' => config('services.firebase.project_id'),
            'client_email' => config('services.firebase.client_email'),
            'private_key' => config('services.firebase.private_key'),
        ]);
    }

    private function normalizeCredentials(array $credentials): array
    {
        $credentials['private_key'] = str_replace('\n', "\n", (string) ($credentials['private_key'] ?? ''));

        return $credentials;
    }
}
