<?php

namespace App\Mail;

use App\Models\Intervention;
use Illuminate\Bus\Queueable;
use Illuminate\Mail\Mailable;
use Illuminate\Queue\SerializesModels;

class InterventionFinished extends Mailable
{
    use Queueable, SerializesModels;

    public string $duration;

    public function __construct(public Intervention $intervention, int $totalSeconds)
    {
        $this->duration = $this->formatDuration($totalSeconds);
    }

    public function build(): self
    {
        $clientName = $this->intervention->client?->name ?? 'Cliente';

        return $this->subject('Intervencao concluida - ' . $clientName)
            ->view('emails.interventions.finished');
    }

    private function formatDuration(int $seconds): string
    {
        $safeSeconds = max(0, $seconds);
        $hours = intdiv($safeSeconds, 3600);
        $minutes = intdiv($safeSeconds % 3600, 60);
        $secs = $safeSeconds % 60;

        return sprintf('%dh %02dm %02ds', $hours, $minutes, $secs);
    }
}
