<?php

namespace Tests\Feature\Api;

use App\Models\Client;
use App\Models\ClientCredential;
use App\Models\ClientCredentialObject;
use App\Models\Installment;
use App\Models\Invoice;
use App\Models\Project;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ClientCredentialObjectTransferApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_admin_can_transfer_object_and_attached_project_to_another_client(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $sourceClient = Client::create(['name' => 'Cliente Origem']);
        $targetClient = Client::create(['name' => 'Cliente Destino']);
        $project = Project::create([
            'client_id' => $sourceClient->id,
            'name' => 'Projeto Alpha',
            'status' => 'em_andamento',
        ]);
        $object = ClientCredentialObject::create([
            'client_id' => $sourceClient->id,
            'project_id' => $project->id,
            'name' => 'Objeto Alpha',
        ]);

        ClientCredential::create([
            'client_id' => $sourceClient->id,
            'object_id' => $object->id,
            'label' => 'Backoffice',
            'password' => 'segredo-1',
        ]);

        ClientCredential::create([
            'client_id' => $sourceClient->id,
            'project_id' => $project->id,
            'label' => 'Servidor',
            'password' => 'segredo-2',
        ]);

        $invoice = Invoice::create([
            'client_id' => $sourceClient->id,
            'project_id' => $project->id,
            'number' => 'WD-2026-0001',
            'total' => 100,
            'status' => 'pendente',
        ]);

        Installment::create([
            'client_id' => $sourceClient->id,
            'project_id' => $project->id,
            'invoice_id' => $invoice->id,
            'amount' => 100,
        ]);

        $response = $this->postJson(
            "/api/v1/clients/{$sourceClient->id}/credential-objects/{$object->id}/transfer",
            ['target_client_id' => $targetClient->id],
        );

        $response
            ->assertOk()
            ->assertJsonPath('data.object.client_id', $targetClient->id)
            ->assertJsonPath('data.object.project_id', $project->id)
            ->assertJsonPath('data.target_client.id', $targetClient->id);

        $this->assertDatabaseHas('client_credential_objects', [
            'id' => $object->id,
            'client_id' => $targetClient->id,
        ]);

        $this->assertDatabaseHas('projects', [
            'id' => $project->id,
            'client_id' => $targetClient->id,
        ]);

        $this->assertDatabaseHas('client_credentials', [
            'object_id' => $object->id,
            'client_id' => $targetClient->id,
        ]);

        $this->assertDatabaseHas('client_credentials', [
            'project_id' => $project->id,
            'client_id' => $targetClient->id,
        ]);

        $this->assertDatabaseHas('invoices', [
            'id' => $invoice->id,
            'client_id' => $targetClient->id,
        ]);

        $this->assertDatabaseHas('installments', [
            'project_id' => $project->id,
            'client_id' => $targetClient->id,
        ]);
    }

    public function test_admin_can_promote_object_to_client_and_create_portal_user(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $sourceClient = Client::create(['name' => 'Cliente Mãe']);
        $project = Project::create([
            'client_id' => $sourceClient->id,
            'name' => 'Projeto Beta',
            'status' => 'planeamento',
        ]);
        $object = ClientCredentialObject::create([
            'client_id' => $sourceClient->id,
            'project_id' => $project->id,
            'name' => 'Andreia Emagrecimento',
            'notes' => 'Objeto que vai ser promovido.',
        ]);

        $response = $this->postJson(
            "/api/v1/clients/{$sourceClient->id}/credential-objects/{$object->id}/promote",
            [
                'name' => 'Andreia Emagrecimento',
                'company' => 'Andreia Emagrecimento',
                'email' => 'andreia@example.com',
                'phone' => '910000000',
                'vat' => '123456789',
                'address' => 'Rua Nova',
                'notes' => 'Novo cliente direto',
                'portal_email' => 'portal.andreia@example.com',
                'portal_password' => 'TempPass123',
            ],
        );

        $response
            ->assertCreated()
            ->assertJsonPath('data.client.name', 'Andreia Emagrecimento')
            ->assertJsonPath('data.portal_user.email', 'portal.andreia@example.com')
            ->assertJsonPath('data.temporary_password', 'TempPass123');

        $newClientId = $response->json('data.client.id');

        $this->assertDatabaseHas('clients', [
            'id' => $newClientId,
            'name' => 'Andreia Emagrecimento',
            'email' => 'andreia@example.com',
        ]);

        $this->assertDatabaseHas('users', [
            'client_id' => $newClientId,
            'email' => 'portal.andreia@example.com',
            'role' => User::ROLE_CLIENT,
        ]);

        $this->assertDatabaseHas('client_credential_objects', [
            'id' => $object->id,
            'client_id' => $newClientId,
        ]);

        $this->assertDatabaseHas('projects', [
            'id' => $project->id,
            'client_id' => $newClientId,
        ]);
    }
}
