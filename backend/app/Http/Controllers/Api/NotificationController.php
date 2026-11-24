<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\UserNotificationResource;
use App\Models\UserNotification;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class NotificationController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $notifications = $request->user()->notifications()
            ->latest()
            ->paginate(20);

        return response()->json(UserNotificationResource::collection($notifications));
    }

    public function unreadCount(Request $request): JsonResponse
    {
        $count = $request->user()->notifications()
            ->whereNull('read_at')
            ->count();

        return response()->json(['unread_count' => $count]);
    }

    public function markRead(Request $request, UserNotification $notification): JsonResponse
    {
        abort_if($notification->user_id !== $request->user()->id, 403, 'Esta notificação não é sua.');

        $notification->update(['read_at' => now()]);

        return response()->json([
            'message' => 'Notificação marcada como lida.',
            'notification' => new UserNotificationResource($notification->refresh()),
        ]);
    }

    public function markAllRead(Request $request): JsonResponse
    {
        $request->user()->notifications()
            ->whereNull('read_at')
            ->update(['read_at' => now()]);

        return response()->json(['message' => 'Todas as notificações foram marcadas como lidas.']);
    }

    public function destroy(Request $request, UserNotification $notification): JsonResponse
    {
        abort_if($notification->user_id !== $request->user()->id, 403, 'Esta notificação não é sua.');

        $notification->delete();

        return response()->json(['message' => 'Notificação removida.']);
    }
}
