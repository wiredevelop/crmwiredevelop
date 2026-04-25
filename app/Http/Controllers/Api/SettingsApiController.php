<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Api\Concerns\RespondsWithJson;
use App\Http\Controllers\Controller;
use App\Models\Setting;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Symfony\Component\Process\Process;

class SettingsApiController extends Controller
{
    use RespondsWithJson;

    public function index(): JsonResponse
    {
        $salesGoal = Setting::where('key', 'sales_goal_year')->value('value');

        return $this->success([
            'sales_goal' => $salesGoal !== null ? (float) $salesGoal : null,
            'ide_status' => $this->ideStatus(),
        ]);
    }

    public function updateSalesGoal(Request $request): JsonResponse
    {
        $data = $request->validate([
            'sales_goal_year' => ['nullable', 'numeric', 'min:0'],
        ]);

        $value = $data['sales_goal_year'] ?? null;
        Setting::updateOrCreate(['key' => 'sales_goal_year'], ['value' => $value !== null ? (string) $value : null]);

        return $this->success([
            'sales_goal' => $value !== null ? (float) $value : null,
        ], 'Meta de vendas atualizada.');
    }

    public function toggleIde(): JsonResponse
    {
        $status = $this->ideStatus();
        $action = $status['state'] === 'active' ? 'stop' : 'start';
        $service = $this->ideServiceName();

        $result = $this->runSystemctl([$action, $service]);
        if (!$result['ok']) {
            return $this->error($result['output'] ? "Falha ao atualizar IDE: {$result['output']}" : 'Falha ao atualizar IDE.', [], 500);
        }

        return $this->success([
            'ide_status' => $this->ideStatus(),
        ], $action === 'start' ? 'IDE ativada.' : 'IDE desativada.');
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

        return ['state' => $state, 'raw' => $result['output']];
    }

    private function runSystemctl(array $args): array
    {
        $process = new Process(array_merge($this->systemctlCommandParts(), $args));
        $process->setTimeout(5);
        $process->run();

        $output = trim($process->getOutput());
        if ($output === '') {
            $output = trim($process->getErrorOutput());
        }

        return ['ok' => $process->getExitCode() === 0, 'output' => $output];
    }
}
