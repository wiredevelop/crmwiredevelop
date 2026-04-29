<?php

namespace App\Mail;

use App\Models\Intervention;
use Illuminate\Bus\Queueable;
use Illuminate\Mail\Mailable;
use Illuminate\Queue\SerializesModels;

class InterventionStarted extends Mailable
{
    use Queueable, SerializesModels;

    public function __construct(public Intervention $intervention) {}

    public function build(): self
    {
        $clientName = $this->intervention->client?->name ?? 'Cliente';

        return $this->subject('Intervencao iniciada - '.$clientName)
            ->view('emails.interventions.started');
    }
}
