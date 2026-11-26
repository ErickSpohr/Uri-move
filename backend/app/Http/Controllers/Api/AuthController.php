<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\LoginRequest;
use App\Http\Requests\RegisterRequest;
use App\Http\Requests\ResendCodeRequest;
use App\Http\Requests\VerifyEmailRequest;
use App\Http\Resources\UserResource;
use App\Models\User;
use App\Services\EmailVerificationService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Symfony\Component\HttpFoundation\Response;

class AuthController extends Controller
{
    public function __construct(private readonly EmailVerificationService $emailVerification) {}

    public function register(RegisterRequest $request): JsonResponse
    {
        // Se o e-mail com o código não puder ser enviado, o cadastro é desfeito:
        // assim o usuário pode tentar de novo sem cair em "e-mail já cadastrado".
        DB::transaction(function () use ($request) {
            $user = User::create($request->safe()->except(['password_confirmation']));
            $this->emailVerification->send($user);
        });

        return response()->json([
            'message' => 'Cadastro realizado. Enviamos um código de verificação para o seu e-mail institucional.',
        ], Response::HTTP_CREATED);
    }

    public function verifyEmail(VerifyEmailRequest $request): JsonResponse
    {
        $user = User::where('email', $request->email)->firstOrFail();

        if ($user->isVerified()) {
            return response()->json(['message' => 'Este e-mail já foi verificado.']);
        }

        if (! $this->emailVerification->verify($user, $request->code)) {
            return response()->json([
                'message' => 'Código inválido ou expirado.',
                'errors' => ['code' => ['Código inválido ou expirado.']],
            ], Response::HTTP_UNPROCESSABLE_ENTITY);
        }

        $token = $user->createToken('mobile')->plainTextToken;

        return response()->json([
            'message' => 'E-mail verificado com sucesso.',
            'token' => $token,
            'user' => UserResource::owner($user->load('course', 'campus')),
        ]);
    }

    public function resendCode(ResendCodeRequest $request): JsonResponse
    {
        $user = User::where('email', $request->email)->firstOrFail();

        if ($user->isVerified()) {
            return response()->json(['message' => 'Este e-mail já foi verificado.']);
        }

        $this->emailVerification->send($user);

        return response()->json(['message' => 'Um novo código foi enviado para o seu e-mail.']);
    }

    public function login(LoginRequest $request): JsonResponse
    {
        if (! Auth::attempt($request->only('email', 'password'))) {
            return response()->json([
                'message' => 'Credenciais inválidas.',
                'errors' => ['email' => ['E-mail ou senha incorretos.']],
            ], Response::HTTP_UNAUTHORIZED);
        }

        $user = User::where('email', $request->email)->first();

        if (! $user->isVerified()) {
            $codeSent = ! $this->emailVerification->hasRecentCode($user);

            if ($codeSent) {
                $this->emailVerification->send($user);
            }

            return response()->json([
                'message' => $codeSent
                    ? 'E-mail ainda não verificado. Um novo código foi enviado.'
                    : 'E-mail ainda não verificado. Use o código enviado recentemente.',
                'requires_email_verification' => true,
                'user' => UserResource::owner($user->load('course', 'campus')),
            ], Response::HTTP_FORBIDDEN);
        }

        if (! $user->is_active) {
            return response()->json([
                'message' => 'Sua conta está inativa. Entre em contato com o suporte.',
            ], Response::HTTP_FORBIDDEN);
        }

        $token = $user->createToken('mobile')->plainTextToken;

        return response()->json([
            'message' => 'Autenticado com sucesso.',
            'token' => $token,
            'user' => UserResource::owner($user->load('course', 'campus')),
        ]);
    }

    public function logout(Request $request): JsonResponse
    {
        $request->user()->currentAccessToken()->delete();

        return response()->json(['message' => 'Sessão encerrada.']);
    }
}
