<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Contracts\Encryption\DecryptException;
use Illuminate\Encryption\Encrypter;
use Illuminate\Support\Facades\Crypt;

class ClientCredential extends Model
{
    use HasFactory;

    protected $fillable = [
        'client_id',
        'project_id',
        'object_id',
        'label',
        'username',
        'password',
        'url',
        'notes',
    ];

    public function client()
    {
        return $this->belongsTo(Client::class);
    }

    public function project()
    {
        return $this->belongsTo(Project::class);
    }

    public function object()
    {
        return $this->belongsTo(ClientCredentialObject::class, 'object_id');
    }

    public function getPasswordAttribute($value): ?string
    {
        if ($value === null || $value === '') {
            return $value;
        }

        return $this->decryptPasswordPayload($value)['plaintext'];
    }

    public function setPasswordAttribute($value): void
    {
        if ($value === null || $value === '') {
            $this->attributes['password'] = $value;

            return;
        }

        $this->attributes['password'] = Crypt::encryptString((string) $value);
    }

    public function normalizePasswordEncryption(): bool
    {
        if (! $this->exists) {
            return false;
        }

        $raw = $this->getRawOriginal('password');

        if (! is_string($raw) || $raw === '') {
            return false;
        }

        $decrypted = $this->decryptPasswordPayload($raw);

        if ($decrypted['plaintext'] === null || $decrypted['source'] === 'current' || $decrypted['source'] === 'invalid') {
            return false;
        }

        $this->password = $decrypted['plaintext'];
        $this->saveQuietly();

        return true;
    }

    private function looksEncryptedPayload(string $value): bool
    {
        $decoded = base64_decode($value, true);

        if ($decoded === false) {
            return false;
        }

        $payload = json_decode($decoded, true);

        return is_array($payload)
            && isset($payload['iv'], $payload['value'], $payload['mac']);
    }

    private function decryptPasswordPayload(string $value): array
    {
        try {
            return [
                'plaintext' => Crypt::decryptString($value),
                'source' => 'current',
            ];
        } catch (DecryptException) {
            foreach (config('app.previous_keys', []) as $key) {
                $encrypter = $this->makeEncrypter($key);

                if (! $encrypter) {
                    continue;
                }

                try {
                    return [
                        'plaintext' => $encrypter->decryptString($value),
                        'source' => 'previous',
                    ];
                } catch (DecryptException) {
                    continue;
                }
            }
        }

        return [
            'plaintext' => $this->looksEncryptedPayload($value) ? null : $value,
            'source' => $this->looksEncryptedPayload($value) ? 'invalid' : 'plaintext',
        ];
    }

    private function makeEncrypter(mixed $key): ?Encrypter
    {
        if (! is_string($key) || trim($key) === '') {
            return null;
        }

        $parsedKey = str_starts_with($key, 'base64:')
            ? base64_decode(substr($key, 7), true)
            : $key;

        if (! is_string($parsedKey) || $parsedKey === '') {
            return null;
        }

        return new Encrypter($parsedKey, (string) config('app.cipher', 'AES-256-CBC'));
    }
}
