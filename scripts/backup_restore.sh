#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${ROOT_DIR:-$(pwd)}"
COMMANDS_DIR="$ROOT_DIR/app/Console/Commands"

usage() {
  echo "Usage: $(basename "$0") [install]"
  echo "  install   Create backup/restore artisan command files in the current project"
}

cmd=${1:-install}

if [[ "$cmd" != "install" ]]; then
  usage
  exit 1
fi

mkdir -p "$COMMANDS_DIR"

cat > "$COMMANDS_DIR/AppBackupSnapshot.php" <<'PHP'
<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\Config;
use Symfony\Component\Process\Process;

class AppBackupSnapshot extends Command
{
    protected $signature = 'app:backup-snapshot {--name=}';
    protected $description = 'Cria um snapshot de código do projeto Laravel';

    public function handle()
    {
        $projectPath = base_path();
        $backupBase  = (string) env(
            'APP_BACKUP_BASE',
            '/var/bcks/' . basename($projectPath) . '/code'
        );
        $name = $this->option('name')
            ?: 'snapshot_' . now()->format('Y-m-d_H-i');

        $tmpDir = sys_get_temp_dir() . '/app_backup_' . $name;
        $dbFull = $tmpDir . '/db_full.sql';
        $dbSchema = $tmpDir . '/db_schema.sql';

        $backupFile = "{$backupBase}/{$name}.tar.gz";

        $this->info("📦 Backup snapshot: {$name}");
        $this->line("📂 Projeto: {$projectPath}");
        $this->line("💾 Destino: {$backupFile}");
        $this->line("🗄️  DB dumps: {$dbFull} | {$dbSchema}");

        if (!is_dir($backupBase)) {
            $this->line('📁 Diretório de backup não existe. A criar...');
            mkdir($backupBase, 0700, true);
        }

        $this->newLine();
        $this->info('🔄 A criar dumps da base de dados…');

        if (!is_dir($tmpDir)) {
            mkdir($tmpDir, 0700, true);
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

        $dumpBase = [
            'mysqldump',
            '-h', $dbHost,
            '-P', $dbPort,
            '-u', $dbUser,
            '--databases', $dbName,
            '--single-transaction',
            '--skip-lock-tables',
        ];

        $dumpEnv = [
            'MYSQL_PWD' => $dbPass,
        ];

        $fullDump = new Process(array_merge($dumpBase, ['--result-file=' . $dbFull]), null, $dumpEnv);
        $fullDump->setTimeout(null);
        $fullDump->run();

        if (!$fullDump->isSuccessful()) {
            $this->error('❌ Erro ao criar dump completo da DB');
            return Command::FAILURE;
        }

        $schemaDump = new Process(array_merge($dumpBase, ['--no-data', '--result-file=' . $dbSchema]), null, $dumpEnv);
        $schemaDump->setTimeout(null);
        $schemaDump->run();

        if (!$schemaDump->isSuccessful()) {
            $this->error('❌ Erro ao criar dump de schema da DB');
            return Command::FAILURE;
        }

        $this->newLine();
        $this->info('🔄 A criar arquivo…');

        $progress = $this->output->createProgressBar(100);
        $progress->start();

        $command = [
            'tar',
            '--exclude=vendor',
            '--exclude=node_modules',
            '--exclude=storage/framework',
            '--exclude=storage/logs',
            '--exclude=public/build',
            '-czf',
            $backupFile,
            '-C', $projectPath, '.',
            '-C', $tmpDir, 'db_full.sql',
            '-C', $tmpDir, 'db_schema.sql',
        ];

        $process = new Process($command);
        $process->setTimeout(null);

        $process->run(function () use ($progress) {
            if ($progress->getProgress() < 95) {
                $progress->advance(5);
            }
        });

        $progress->finish();
        $this->newLine(2);

        if (!$process->isSuccessful()) {
            $this->error('❌ Erro ao criar backup');
            return Command::FAILURE;
        }

        $this->info('✅ Backup criado com sucesso');
        @unlink($dbFull);
        @unlink($dbSchema);
        @rmdir($tmpDir);
        return Command::SUCCESS;
    }
}
PHP

cat > "$COMMANDS_DIR/AppRestoreSnapshot.php" <<'PHP'
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
PHP

echo "✅ Comandos criados:"
echo " - $COMMANDS_DIR/AppBackupSnapshot.php"
echo " - $COMMANDS_DIR/AppRestoreSnapshot.php"
echo "Agora podes correr: php artisan app:backup-snapshot / app:restore-snapshot"
