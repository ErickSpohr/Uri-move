<?php

namespace App\Providers;

use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\ServiceProvider;
use Symfony\Component\HttpFoundation\Response;

class AppServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        //
    }

    public function boot(): void
    {
        $this->configureRateLimiting();
    }

    /**
     * Limites das rotas públicas de autenticação.
     * Chave por e-mail impede força bruta contra uma conta; chave por IP limita varredura de contas.
     */
    private function configureRateLimiting(): void
    {
        $email = fn (Request $request): string => mb_strtolower(trim((string) $request->input('email')));

        $tooMany = fn (string $message) => fn (Request $request, array $headers) => response()->json(
            ['message' => $message],
            Response::HTTP_TOO_MANY_REQUESTS,
            $headers,
        );

        RateLimiter::for('login', fn (Request $request) => [
            Limit::perMinute(5)->by('email:'.$email($request).'|'.$request->ip())
                ->response($tooMany('Muitas tentativas de login. Aguarde um minuto e tente novamente.')),
            Limit::perMinute(30)->by('ip:'.$request->ip())
                ->response($tooMany('Muitas tentativas de login. Aguarde um minuto e tente novamente.')),
        ]);

        // Código de 6 dígitos válido por 10 min: 5 tentativas por janela tornam força bruta inviável.
        RateLimiter::for('verify-email', fn (Request $request) => [
            Limit::perMinutes(10, 5)->by('email:'.$email($request))
                ->response($tooMany('Muitas tentativas de verificação. Solicite um novo código em alguns minutos.')),
            Limit::perMinute(30)->by('ip:'.$request->ip())
                ->response($tooMany('Muitas tentativas de verificação. Aguarde um minuto.')),
        ]);

        // Cada requisição envia e-mail: limita custo na Brevo e spam ao destinatário.
        RateLimiter::for('send-code', fn (Request $request) => [
            Limit::perMinutes(10, 3)->by('email:'.$email($request))
                ->response($tooMany('Muitos códigos solicitados para este e-mail. Aguarde alguns minutos.')),
            Limit::perMinute(10)->by('ip:'.$request->ip())
                ->response($tooMany('Muitas solicitações. Aguarde um minuto.')),
        ]);
    }
}
