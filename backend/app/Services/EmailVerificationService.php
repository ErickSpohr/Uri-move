<?php

namespace App\Services;

use App\Models\EmailVerification;
use App\Models\User;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;
use Throwable;

class EmailVerificationService
{
    public function __construct(private readonly VerificationEmailSender $sender) {}

    public function generateCode(User $user): EmailVerification
    {
        $digits = config('urimove.verification_code.digits', 6);
        $minutes = config('urimove.verification_code.expires_at_minutes', 10);

        $code = Str::of((string) random_int(10 ** ($digits - 1), (10 ** $digits) - 1))
            ->toString();

        return $user->emailVerifications()->create([
            'code' => $code,
            'expires_at' => now()->addMinutes($minutes),
        ]);
    }

    public function send(User $user): void
    {
        $record = $this->generateCode($user);

        $minutes = config('urimove.verification_code.expires_at_minutes', 10);
        $subject = 'Seu código de verificação — URI Move';
        $text = "Seu código de verificação do URI Move é: {$record->code}.\n\n"
            ."Ele expira em {$minutes} minutos. Não compartilhe este código.\n"
            .'Se você não solicitou este cadastro, ignore este e-mail.';

        try {
            $this->sender->send($user->email, $subject, $text);
        } catch (Throwable) {
            $record->delete();

            throw ValidationException::withMessages([
                'email' => 'Não foi possível enviar o código agora. Tente reenviar em alguns instantes.',
            ]);
        }
    }

    public function verify(User $user, string $code): bool
    {
        $record = $user->emailVerifications()
            ->where('code', $code)
            ->whereNull('used_at')
            ->latest()
            ->first();

        if (! $record || ! $record->isValid()) {
            return false;
        }

        $record->update(['used_at' => now()]);
        $user->forceFill(['email_verified_at' => now()])->save();

        return true;
    }
}
