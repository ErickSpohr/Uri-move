<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Message;
use App\Models\Ride;
use App\Models\RideChatMessage;
use App\Models\RidePassenger;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ChatUnreadController extends Controller
{
    /**
     * Mensagens não lidas do usuário: chat em grupo por carona ativa e conversas privadas por remetente.
     * Resposta: {total, rides: [{ride_id, count}], private: [{ride_id, user_id, count}]}.
     */
    public function __invoke(Request $request): JsonResponse
    {
        $userId = $request->user()->id;

        $activeRideIds = Ride::query()
            ->whereNotIn('status', [Ride::STATUS_CANCELLED, Ride::STATUS_COMPLETED])
            ->where(function ($query) use ($userId) {
                $query->where('driver_id', $userId)
                    ->orWhereHas('passengers', fn ($passengers) => $passengers
                        ->where('passenger_id', $userId)
                        ->whereIn('status', [RidePassenger::STATUS_CONFIRMED, RidePassenger::STATUS_COMPLETED]));
            })
            ->pluck('id');

        $rides = RideChatMessage::query()
            ->leftJoin('ride_chat_reads as reads', function ($join) use ($userId) {
                $join->on('reads.ride_id', '=', 'ride_chat_messages.ride_id')
                    ->where('reads.user_id', '=', $userId);
            })
            ->whereIn('ride_chat_messages.ride_id', $activeRideIds)
            ->where('ride_chat_messages.sender_id', '!=', $userId)
            ->whereRaw('ride_chat_messages.id > coalesce(reads.last_read_message_id, 0)')
            ->groupBy('ride_chat_messages.ride_id')
            ->selectRaw('ride_chat_messages.ride_id, count(*) as count')
            ->get()
            ->map(fn ($row) => ['ride_id' => (int) $row->ride_id, 'count' => (int) $row->count])
            ->values();

        // Só conversas de caronas ainda abertas: as de caronas encerradas não
        // aparecem na lista de conversas e deixariam o contador preso.
        $private = Message::query()
            ->where('receiver_id', $userId)
            ->whereNull('read_at')
            ->whereIn('ride_id', Ride::query()
                ->whereNotIn('status', [Ride::STATUS_CANCELLED, Ride::STATUS_COMPLETED])
                ->select('id'))
            ->groupBy('ride_id', 'sender_id')
            ->selectRaw('ride_id, sender_id, count(*) as count')
            ->get()
            ->map(fn ($row) => [
                'ride_id' => (int) $row->ride_id,
                'user_id' => (int) $row->sender_id,
                'count' => (int) $row->count,
            ])
            ->values();

        return response()->json([
            'total' => $rides->sum('count') + $private->sum('count'),
            'rides' => $rides,
            'private' => $private,
        ]);
    }
}
