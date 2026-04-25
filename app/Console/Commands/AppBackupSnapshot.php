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
