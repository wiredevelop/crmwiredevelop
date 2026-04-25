<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\Config;
use Symfony\Component\Process\Process;

class AppRestoreSnapshot extends Command
{
    protected $signature = 'app:restore-snapshot {file?}';
    protected $description = 'Restaura um snapshot de código Laravel';

    public function handle()
    {
        $projectPath = base_path();
        $backupFile  = $this->argument('file');
        $backupBase  = (string) env(
            'APP_BACKUP_BASE',
            '/var/bcks/' . basename($projectPath) . '/code'
        );

        if ($backupFile === null) {
            if (!is_dir($backupBase)) {
                $this->error("❌ Diretório de backups não existe: {$backupBase}");
                return Command::FAILURE;
            }

            $backups = glob(rtrim($backupBase, '/') . '/*.tar.gz') ?: [];
            if ($backups === []) {
                $this->error('❌ Nenhum backup encontrado.');
                return Command::FAILURE;
            }

            $backupFile = $this->choice(
                'Escolhe o backup',
                $backups,
                0
            );
        }

        if (!file_exists($backupFile)) {
            $this->error("❌ Snapshot não encontrado: {$backupFile}");
            return Command::FAILURE;
        }

        $this->warn('⚠️ ATENÇÃO: isto vai substituir o código atual');
        if (!$this->confirm('Queres continuar?')) {
            $this->info('⛔ Restauro cancelado');
            return Command::SUCCESS;
        }

        $this->newLine();
        $this->info('🔄 A restaurar snapshot…');

        $progress = $this->output->createProgressBar(100);
        $progress->start();

        $process = new Process([
            'tar',
            '-xzf',
            $backupFile,
            '-C',
            $projectPath
        ]);

        $process->setTimeout(null);

        $process->run(function () use ($progress) {
            if ($progress->getProgress() < 95) {
                $progress->advance(5);
            }
        });

        $progress->finish();
        $this->newLine(2);

        if (!$process->isSuccessful()) {
            $this->error('❌ Erro no restauro');
            return Command::FAILURE;
        }

        $this->info('✅ Código restaurado');
        $this->newLine();

        $this->line('📦 A reinstalar dependências PHP...');
        shell_exec('composer install --no-dev --optimize-autoloader');

        $this->line('🎨 A recompilar assets...');
        shell_exec('npm install');
        shell_exec('npm run build');

        if (!$this->confirm('Queres restaurar a base de dados?')) {
            $this->info('🚀 Restauro completo (sem DB)');
            return Command::SUCCESS;
        }

        $method = $this->choice(
            'Como queres restaurar a base de dados?',
            ['migrations', 'sql'],
            0
        );

        if ($method === 'migrations') {
            $this->line('🧱 A correr migrations...');
            shell_exec('php artisan migrate --force');
            $this->info('🚀 Restauro completo');
            return Command::SUCCESS;
        }

        $sqlFile = $this->choice(
            'Qual ficheiro SQL queres importar?',
            ['db_full.sql', 'db_schema.sql'],
            0
        );

        $sqlPath = $projectPath . DIRECTORY_SEPARATOR . $sqlFile;
        if (!file_exists($sqlPath)) {
            $this->error("❌ Ficheiro SQL não encontrado: {$sqlPath}");
            return Command::FAILURE;
        }

        $db = Config::get('database.connections.mysql', []);
        $dbHost = (string) ($db['host'] ?? '127.0.0.1');
        $dbPort = (string) ($db['port'] ?? '3306');
        $dbName = (string) ($db['database'] ?? '');
        $dbUser = (string) ($db['username'] ?? '');
        $dbPass = (string) ($db['password'] ?? '');

        if ($dbName === '' || $dbUser === '') {
            $this->error('❌ DB config em falta. Verifica database.php ou .env.');
            return Command::FAILURE;
        }

        $this->line("🗄️  A importar {$sqlFile}...");
        $input = fopen($sqlPath, 'rb');
        if ($input === false) {
            $this->error('❌ Não foi possível abrir o ficheiro SQL.');
            return Command::FAILURE;
        }

        $process = new Process(
            ['mysql', '-h', $dbHost, '-P', $dbPort, '-u', $dbUser, $dbName],
            null,
            ['MYSQL_PWD' => $dbPass],
            $input
        );
        $process->setTimeout(null);
        $process->run();
        fclose($input);

        if (!$process->isSuccessful()) {
            $this->error('❌ Erro ao importar a base de dados');
            return Command::FAILURE;
        }

        $this->info('🚀 Restauro completo');
        return Command::SUCCESS;
    }
}
