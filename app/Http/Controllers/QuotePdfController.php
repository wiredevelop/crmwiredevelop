<?php

namespace App\Http\Controllers;

use App\Models\Quote;
use App\Support\CompanySettings;
use Symfony\Component\Process\Process;

class QuotePdfController extends Controller
{
    public function generate(Quote $quote)
    {
        $quote->load(['project', 'project.client', 'quoteProducts']);

        // 1️⃣ Render Blade para HTML
        $html = view('pdf.quote', [
            'quote' => $quote,
            'project' => $quote->project,
            'client' => $quote->project->client,
            'company' => CompanySettings::get(),
        ])->render();

        $tmpHtml = storage_path("app/tmp/quote_{$quote->id}.html");
        $tmpPdf = storage_path("app/tmp/quote_{$quote->id}.pdf");

        if (! is_dir(storage_path('app/tmp'))) {
            mkdir(storage_path('app/tmp'), 0755, true);
        }

        file_put_contents($tmpHtml, $html);

        // 2️⃣ Chamar Puppeteer
        $process = new Process([
            'node',
            '/var/www/puppeteer-pdf/render-quote.js',
            $tmpHtml,
            $tmpPdf,
        ]);

        $process->setTimeout(60);
        $process->run();

        if (! $process->isSuccessful()) {
            throw new \RuntimeException($process->getErrorOutput());
        }

        // 3️⃣ Devolver PDF
        return response()->file($tmpPdf)->deleteFileAfterSend(true);
    }
}
