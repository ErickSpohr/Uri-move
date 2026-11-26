<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\PushSubscription;
use App\Services\WebPush\WebPushSender;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class PushSubscriptionController extends Controller
{
    public function publicKey(WebPushSender $sender): JsonResponse
    {
        return response()->json(['public_key' => $sender->publicKey()]);
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'endpoint' => ['required', 'string', 'url:https', 'max:2000'],
            'keys.p256dh' => ['required', 'string', 'regex:/^[A-Za-z0-9_-]{86,88}$/'],
            'keys.auth' => ['required', 'string', 'regex:/^[A-Za-z0-9_-]{20,24}$/'],
        ]);

        // O mesmo navegador pode trocar de conta: o endpoint passa a pertencer ao usuário atual.
        PushSubscription::query()->updateOrCreate(
            ['endpoint_hash' => PushSubscription::hashEndpoint($data['endpoint'])],
            [
                'user_id' => $request->user()->id,
                'endpoint' => $data['endpoint'],
                'p256dh' => $data['keys']['p256dh'],
                'auth' => $data['keys']['auth'],
            ],
        );

        return response()->json(['message' => 'Notificações ativadas neste dispositivo.'], 201);
    }

    public function destroy(Request $request): JsonResponse
    {
        $data = $request->validate(['endpoint' => ['required', 'string', 'max:2000']]);

        PushSubscription::query()
            ->where('user_id', $request->user()->id)
            ->where('endpoint_hash', PushSubscription::hashEndpoint($data['endpoint']))
            ->delete();

        return response()->json(['message' => 'Notificações desativadas neste dispositivo.']);
    }
}
