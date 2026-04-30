<?php

namespace App\Console\Commands;

use App\Models\Invoice;
use App\Support\ActivityNotificationService;
use Illuminate\Console\Command;

class SendPendingInvoiceReminders extends Command
{
    protected $signature = 'notifications:send-pending-reminders';

    protected $description = 'Send recurring push reminders for pending invoices.';

    public function handle(ActivityNotificationService $notifications): int
    {
        $rows = Invoice::query()
            ->with('client:id,name')
            ->where('status', 'pendente')
            ->where(function ($query) {
                $query
                    ->whereDate('due_at', '<=', now()->toDateString())
                    ->orWhere(function ($subQuery) {
                        $subQuery
                            ->whereNull('due_at')
                            ->whereDate('issued_at', '<=', now()->subDays(7)->toDateString());
                    });
            })
            ->get()
            ->groupBy('client_id');

        foreach ($rows as $clientId => $invoices) {
            $client = $invoices->first()?->client;
            if (! $client) {
                continue;
            }

            $notifications->notifyPendingInvoiceReminder(
                (int) $clientId,
                $client->name,
                $invoices->count(),
                (float) $invoices->sum('total'),
            );
        }

        $this->info('Pending invoice reminders processed.');

        return self::SUCCESS;
    }
}
