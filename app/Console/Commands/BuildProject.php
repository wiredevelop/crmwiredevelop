<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;

class BuildProject extends Command
{
    protected $signature = 'app:build';

    protected $description = 'Build frontend + clear Laravel cache';

    public function handle()
    {
        $this->info('Clear log...');
        exec('echo "" > storage/logs/laravel.log', $output1);

        $this->info('🔧 Installing npm deps...');
        exec('npm install', $output2);

        $this->info('🚀 Building assets...');
        exec('npm run build', $output3);

        $this->info('🧹 Clearing Laravel cache...');
        exec('php artisan optimize:clear', $output4);

        $this->info('✅ Build completed successfully!');

        return Command::SUCCESS;
    }
}
