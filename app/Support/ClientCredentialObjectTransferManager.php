<?php

namespace App\Support;

use App\Models\Client;
use App\Models\ClientCredential;
use App\Models\ClientCredentialObject;
use App\Models\Installment;
use App\Models\Invoice;
use App\Models\Project;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class ClientCredentialObjectTransferManager
{
    public function __construct(
        private readonly ClientPortalManager $portalManager,
    ) {
    }

    public function transfer(ClientCredentialObject $object, Client $targetClient): ClientCredentialObject
    {
        $object->loadMissing('project');

        if ((int) $object->client_id === (int) $targetClient->id) {
            throw ValidationException::withMessages([
                'target_client_id' => ['Selecione um cliente diferente para a transferência.'],
            ]);
        }

        return DB::transaction(function () use ($object, $targetClient) {
            $object->forceFill([
                'client_id' => $targetClient->id,
            ])->save();

            ClientCredential::query()
                ->where('object_id', $object->id)
                ->update(['client_id' => $targetClient->id]);

            if ($object->project_id) {
                $this->moveProjectOwnership($object->project_id, $targetClient->id);
            }

            return $object->fresh(['project']);
        });
    }

    public function promote(
        ClientCredentialObject $object,
        array $clientData,
        string $portalEmail,
        ?string $temporaryPassword = null,
    ): array {
        return DB::transaction(function () use ($object, $clientData, $portalEmail, $temporaryPassword) {
            $client = Client::create($clientData);
            [$user, $generatedPassword] = $this->portalManager->createPortalUser(
                $client,
                $portalEmail,
                $temporaryPassword,
            );

            $transferredObject = $this->transfer($object, $client);

            return [$client->fresh('user'), $user->fresh(), $generatedPassword, $transferredObject];
        });
    }

    private function moveProjectOwnership(int $projectId, int $targetClientId): void
    {
        Project::query()
            ->whereKey($projectId)
            ->update(['client_id' => $targetClientId]);

        ClientCredential::query()
            ->where('project_id', $projectId)
            ->update(['client_id' => $targetClientId]);

        Invoice::query()
            ->where('project_id', $projectId)
            ->update(['client_id' => $targetClientId]);

        Installment::query()
            ->where('project_id', $projectId)
            ->update(['client_id' => $targetClientId]);
    }
}
