<?php

namespace App\Support;

use App\Mail\ClientTemporaryPasswordMail;
use App\Models\Client;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

class ClientPortalManager
{
    public function createPortalUser(Client $client, ?string $email = null, ?string $temporaryPassword = null): array
    {
        if ($client->user) {
            throw ValidationException::withMessages([
                'portal_user' => ['Este cliente já tem um utilizador associado.'],
            ]);
        }

        $portalEmail = strtolower(trim((string) ($email ?: $client->email)));

        if ($portalEmail === '') {
            throw ValidationException::withMessages([
                'portal_email' => ['Define um email para criar o acesso do cliente.'],
            ]);
        }

        if (User::where('email', $portalEmail)->exists()) {
            throw ValidationException::withMessages([
                'portal_email' => ['Já existe um utilizador com este email.'],
            ]);
        }

        $password = $temporaryPassword ?: $this->generateTemporaryPassword();

        $user = DB::transaction(function () use ($client, $portalEmail, $password) {
            return User::create([
                'name' => $client->name,
                'email' => $portalEmail,
                'role' => User::ROLE_CLIENT,
                'client_id' => $client->id,
                'password' => $password,
                'must_change_password' => true,
            ]);
        });

        return [$user, $password];
    }

    public function regenerateTemporaryPassword(Client $client, string $deliveryMode = 'copy'): array
    {
        $user = $client->user;

        if (! $user) {
            throw ValidationException::withMessages([
                'portal_user' => ['Este cliente ainda não tem acesso criado.'],
            ]);
        }

        $temporaryPassword = $this->generateTemporaryPassword();

        DB::transaction(function () use ($user, $temporaryPassword) {
            $user->forceFill([
                'password' => $temporaryPassword,
                'must_change_password' => true,
                'remember_token' => Str::random(60),
            ])->save();

            $user->tokens()->delete();
        });

        if ($deliveryMode === 'email') {
            if (! $user->email) {
                throw ValidationException::withMessages([
                    'portal_email' => ['O utilizador do cliente não tem email definido para envio.'],
                ]);
            }

            Mail::to($user->email)->send(new ClientTemporaryPasswordMail($client, $user, $temporaryPassword));
        }

        return [$user->fresh(), $temporaryPassword];
    }

    public function generateTemporaryPassword(int $length = 12): string
    {
        $alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789';
        $password = '';

        for ($i = 0; $i < $length; $i++) {
            $password .= $alphabet[random_int(0, strlen($alphabet) - 1)];
        }

        return $password;
    }
}
