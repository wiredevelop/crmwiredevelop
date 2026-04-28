<?php

namespace App\Http\Controllers\Concerns;

use App\Models\Client;
use App\Models\Invoice;
use App\Models\Project;
use App\Models\Quote;
use Illuminate\Database\Eloquent\Builder;

trait InteractsWithClientPortalUsers
{
    protected function currentUser()
    {
        return request()->user();
    }

    protected function isClientUser(): bool
    {
        return (bool) $this->currentUser()?->isClientUser();
    }

    protected function currentClientId(): ?int
    {
        return $this->currentUser()?->client_id;
    }

    protected function abortIfClientUser(): void
    {
        abort_if($this->isClientUser(), 403);
    }

    protected function scopeClients(Builder $query): Builder
    {
        if ($this->isClientUser()) {
            $query->whereKey($this->currentClientId());
        }

        return $query;
    }

    protected function scopeByClient(Builder $query, string $column = 'client_id'): Builder
    {
        if ($this->isClientUser()) {
            $query->where($column, $this->currentClientId());
        }

        return $query;
    }

    protected function ensureClientOwnership(Client $client): void
    {
        if ($this->isClientUser()) {
            abort_unless((int) $client->id === (int) $this->currentClientId(), 404);
        }
    }

    protected function ensureProjectOwnership(Project $project): void
    {
        if ($this->isClientUser()) {
            abort_unless((int) $project->client_id === (int) $this->currentClientId(), 404);
        }
    }

    protected function ensureInvoiceOwnership(Invoice $invoice): void
    {
        if ($this->isClientUser()) {
            abort_unless((int) $invoice->client_id === (int) $this->currentClientId(), 404);
        }
    }

    protected function ensureQuoteOwnership(Quote $quote): void
    {
        if ($this->isClientUser()) {
            $quote->loadMissing('project:id,client_id');
            abort_unless((int) $quote->project?->client_id === (int) $this->currentClientId(), 404);
        }
    }
}
