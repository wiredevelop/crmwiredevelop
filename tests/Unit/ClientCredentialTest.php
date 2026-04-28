<?php

namespace Tests\Unit;

use App\Models\ClientCredential;
use Illuminate\Encryption\Encrypter;
use Tests\TestCase;

class ClientCredentialTest extends TestCase
{
    public function test_plain_text_password_is_returned_without_throwing(): void
    {
        $credential = new ClientCredential();
        $credential->setRawAttributes([
            'password' => 'legacy-secret',
        ]);

        $this->assertSame('legacy-secret', $credential->password);
    }

    public function test_invalid_encrypted_payload_returns_null(): void
    {
        $credential = new ClientCredential();
        $credential->setRawAttributes([
            'password' => base64_encode(json_encode([
                'iv' => 'invalid',
                'value' => 'invalid',
                'mac' => 'invalid',
            ])),
        ]);

        $this->assertNull($credential->password);
    }

    public function test_password_can_be_decrypted_with_previous_app_key(): void
    {
        $legacyKey = 'base64:+p51BLye9hm7dBD4dVkMPdjcbz1QScaayNmrEn7mHkM=';
        config(['app.previous_keys' => [$legacyKey]]);

        $legacyEncrypted = (new Encrypter(
            base64_decode(substr($legacyKey, 7), true),
            (string) config('app.cipher')
        ))->encryptString('legacy-secret');

        $credential = new ClientCredential();
        $credential->setRawAttributes([
            'password' => $legacyEncrypted,
        ]);

        $this->assertSame('legacy-secret', $credential->password);
    }

    public function test_passwords_are_encrypted_when_set(): void
    {
        $credential = new ClientCredential();
        $credential->password = 'secret-123';

        $this->assertNotSame('secret-123', $credential->getRawOriginal('password'));
        $this->assertSame('secret-123', $credential->password);
    }
}
