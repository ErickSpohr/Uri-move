<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\ForgotPasswordRequest;
use App\Http\Requests\ResetPasswordRequest;
use App\Models\User;
use App\Services\VerificationEmailSender;
use Illuminate\Auth\Events\PasswordReset;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Password;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;
use Throwable;

class PasswordResetController extends Controller
{
    public function forgot(ForgotPasswordRequest $request, VerificationEmailSender $sender): JsonResponse
    {
        Password::sendResetLink($request->validated(), function (User $user, string $token) use ($sender): void {
            $minutes = config('auth.passwords.users.expire', 60);

            try {
                $sender->send($user->email, 'Recuperar senha — URI Move',
                    "Copie este código na tela Esqueci minha senha do URI Move:\n\n{$token}\n\n"
                    ."Ele expira em {$minutes} minutos e só pode ser usado uma vez.\n"
                    .'Se você não solicitou a recuperação, ignore este e-mail.');
            } catch (Throwable) {
                Password::deleteToken($user);

                throw ValidationException::withMessages(['email' => 'Não foi possível enviar o código agora. Tente novamente em alguns instantes.']);
            }
        });

        return response()->json(['message' => 'Se este e-mail estiver cadastrado, você receberá um código de recuperação. Confira também a pasta de spam.']);
    }

    public function reset(ResetPasswordRequest $request): JsonResponse
    {
        $status = DB::transaction(function () use ($request) {
            DB::table(config('auth.passwords.users.table'))->where('email', $request->validated('email'))->lockForUpdate()->first();

            return Password::reset($request->validated(), function (User $user, string $password): void {
                $user->forceFill([
                    'password' => Hash::make($password),
                    'remember_token' => Str::random(60),
                    'email_verified_at' => $user->email_verified_at ?? now(),
                ])->save();
                $user->tokens()->delete();
                $user->emailVerifications()->whereNull('used_at')->update(['used_at' => now()]);
                event(new PasswordReset($user));
            });
        });

        if ($status !== Password::PASSWORD_RESET) {
            throw ValidationException::withMessages(['token' => 'Código inválido ou expirado. Solicite um novo código.']);
        }

        return response()->json(['message' => 'Senha atualizada. Entre com sua nova senha.']);
    }
}
