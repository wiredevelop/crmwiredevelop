<?php

namespace App\Mail;

use App\Models\Client;
use App\Models\User;
use Illuminate\Bus\Queueable;
use Illuminate\Mail\Mailable;
use Illuminate\Mail\Mailables\Content;
use Illuminate\Mail\Mailables\Envelope;
use Illuminate\Queue\SerializesModels;

class ClientTemporaryPasswordMail extends Mailable
{
    use Queueable, SerializesModels;

    public function __construct(
        public Client $client,
        public User $user,
        public string $temporaryPassword,
    ) {}

    public function envelope(): Envelope
    {
        return new Envelope(
            subject: 'Acesso temporário ao WireDevelop CRM',
        );
    }

    public function content(): Content
    {
        return new Content(
            view: 'emails.client-portal-temporary-password',
        );
    }
}
