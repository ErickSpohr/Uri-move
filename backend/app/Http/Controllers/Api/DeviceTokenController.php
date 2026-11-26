<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\DeviceToken;
use App\Services\Fcm\FcmSender;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class DeviceTokenController extends Controller
{
    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'token' => ['required', 'string', 'max:512'],
            'platform' => ['nullable', 'string', 'in:android,ios'],
        ]);

        // O mesmo aparelho pode trocar de conta: o token passa a ser do usuário atual.
        DeviceToken::query()->updateOrCreate(
            ['token' => $data['token']],
            ['user_id' => $request->user()->id, 'platform' => $data['platform'] ?? 'android'],
        );

        return response()->json(['message' => 'Aparelho registrado para notificações.'], 201);
    }

    public function destroy(Request $request): JsonResponse
    {
        $data = $request->validate(['token' => ['required', 'string', 'max:512']]);

        DeviceToken::query()
            ->where('user_id', $request->user()->id)
            ->where('token', $data['token'])
            ->delete();

        return response()->json(['message' => 'Aparelho removido.']);
    }

    /**
     * Envia uma notificação de teste ao próprio usuário e devolve o diagnóstico.
     */
    public function test(Request $request, FcmSender $fcm): JsonResponse
    {
        $report = $fcm->sendToUser(
            $request->user(),
            'Teste do URI Move',
            'Se você está vendo isto, as notificações estão funcionando.',
            ['type' => 'test'],
        );

        return response()->json($report);
    }
}
