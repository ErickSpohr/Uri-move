<?php

namespace App\Services;

use Illuminate\Mail\Message;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Mail;

class VerificationEmailSender
{
    public function send(string $email, string $subject, string $text): void
    {
        if (config('mail.default') === 'brevo') {
            if (! config('services.brevo.key')) {
                throw new \RuntimeException('Brevo is not configured.');
            }

            Http::acceptJson()
                ->withHeaders(['api-key' => config('services.brevo.key')])
                ->connectTimeout(5)
                ->timeout(15)
                ->post('https://api.brevo.com/v3/smtp/email', [
                    'sender' => [
                        'email' => config('mail.from.address'),
                        'name' => config('mail.from.name'),
                    ],
                    'to' => [['email' => $email]],
                    'subject' => $subject,
                    'textContent' => $text,
                    'htmlContent' => nl2br(e($text)),
                ])->throw();
        } else {
            Mail::raw($text, function (Message $message) use ($email, $subject): void {
                $message->to($email)->subject($subject);
            });
        }
    }
}
