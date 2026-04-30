<?php

namespace App\Http\Controllers;

use App\Models\Setting;
use Illuminate\Http\Request;
use Inertia\Inertia;
use Symfony\Component\Process\Process;

class SettingsController extends Controller
{
    public function index()
    {
        $salesGoal = Setting::where('key', 'sales_goal_year')->value('value');
        $terminalSurchargePercent = Setting::where('key', 'terminal_surcharge_percent')->value('value');
        $terminalSurchargeFixed = Setting::where('key', 'terminal_surcharge_fixed')->value('value');

        return Inertia::render('Settings/Index', [
            'salesGoal' => $salesGoal !== null ? (float) $salesGoal : null,
            'terminalSurchargePercent' => $terminalSurchargePercent !== null ? (float) $terminalSurchargePercent : 0.0,
            'terminalSurchargeFixed' => $terminalSurchargeFixed !== null ? (float) $terminalSurchargeFixed : 0.0,
            'ideStatus' => $this->ideStatus(),
        ]);
    }

    public function updateSalesGoal(Request $request)
    {
        $data = $request->validate([
            'sales_goal_year' => ['nullable', 'numeric', 'min:0'],
            'terminal_surcharge_percent' => ['nullable', 'numeric', 'min:0', 'max:99.99'],
            'terminal_surcharge_fixed' => ['nullable', 'numeric', 'min:0'],
        ]);

        $value = $data['sales_goal_year'] ?? null;
        $terminalSurchargePercent = $data['terminal_surcharge_percent'] ?? 0;
        $terminalSurchargeFixed = $data['terminal_surcharge_fixed'] ?? 0;

        Setting::updateOrCreate(
            ['key' => 'sales_goal_year'],
            ['value' => $value !== null ? (string) $value : null]
        );

        Setting::updateOrCreate(
            ['key' => 'terminal_surcharge_percent'],
            ['value' => (string) $terminalSurchargePercent]
        );

        Setting::updateOrCreate(
            ['key' => 'terminal_surcharge_fixed'],
            ['value' => (string) $terminalSurchargeFixed]
        );

        return back()->with('success', 'Definições atualizadas.');
    }

    public function toggleIde(Request $request)
    {
        $status = $this->ideStatus();
        $action = $status['state'] === 'active' ? 'stop' : 'start';
        $service = $this->ideServiceName();

        $result = $this->runSystemctl([$action, $service]);
        if (! $result['ok']) {
            $message = $result['output'] ? "Falha ao atualizar IDE: {$result['output']}" : 'Falha ao atualizar IDE.';

            return back()->with('error', $message);
        }

        return back()->with('success', $action === 'start' ? 'IDE ativada.' : 'IDE desativada.');
    }

    private function ideServiceName(): string
    {
        return (string) config('services.code_server.service', 'code-server@root');
    }

    private function systemctlCommandParts(): array
    {
        $command = (string) config('services.code_server.systemctl', 'systemctl');
        $parts = preg_split('/\s+/', trim($command)) ?: [];

        return $parts ?: ['systemctl'];
    }

    private function ideStatus(): array
    {
        $service = $this->ideServiceName();
        $result = $this->runSystemctl(['is-active', $service]);
        $raw = strtolower(trim($result['output']));
        $knownStates = ['active', 'inactive', 'failed', 'activating', 'deactivating'];
        $state = in_array($raw, $knownStates, true) ? $raw : 'unknown';

        return [
            'state' => $state,
            'raw' => $result['output'],
        ];
    }

    private function runSystemctl(array $args): array
    {
        $process = new Process(array_merge($this->systemctlCommandParts(), $args));
        $process->setTimeout(5);
        $process->run();

        $output = trim($process->getOutput());
        if ($output == '') {
            $output = trim($process->getErrorOutput());
        }

        return [
            'ok' => $process->getExitCode() === 0,
            'output' => $output,
        ];
    }
}
