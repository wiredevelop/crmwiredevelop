<?php

namespace Tests\Feature;

use App\Models\Client;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class DashboardPendingTest extends TestCase
{
    use RefreshDatabase;

    public function test_client_user_can_open_pending_dashboard_page(): void
    {
        $client = Client::create([
            'name' => 'Cliente Teste',
            'email' => 'cliente@example.com',
        ]);

        $user = User::factory()->create([
            'role' => User::ROLE_CLIENT,
            'client_id' => $client->id,
        ]);

        $response = $this
            ->actingAs($user)
            ->get(route('dashboard.pending'));

        $response->assertOk();
    }

    public function test_admin_cannot_open_client_pending_dashboard_page(): void
    {
        $user = User::factory()->create();

        $response = $this
            ->actingAs($user)
            ->get(route('dashboard.pending'));

        $response->assertForbidden();
    }
}
