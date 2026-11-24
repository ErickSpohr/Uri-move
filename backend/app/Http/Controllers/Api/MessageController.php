<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreMessageRequest;
use App\Http\Resources\MessageResource;
use App\Models\Message;
use App\Models\Ride;
use App\Models\RidePassenger;
use App\Models\RideRequest;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class MessageController extends Controller
{
    public function index(Request $request, Ride $ride): JsonResponse
    {
        $this->authorizeParticipant($request, $ride);

        $query = $ride->messages()
            ->with(['sender'])
            ->where(function ($q) use ($request) {
                $q->where('sender_id', $request->user()->id)
                    ->orWhere('receiver_id', $request->user()->id);
            });

        if ($other = $request->filled('user_id') ? (int) $request->user_id : null) {
            $query = $query->where(function ($q) use ($other) {
                $q->where('sender_id', $other)->orWhere('receiver_id', $other);
            });
        }

        $data = $request->validate([
            'after_id' => ['nullable', 'integer', 'min:0'],
        ]);

        // Sem after_id: retorna as 50 mensagens mais recentes em ordem cronológica.
        $messages = isset($data['after_id'])
            ? $query->where('id', '>', $data['after_id'])->orderBy('id')->limit(50)->get()
            : $query->orderByDesc('id')->limit(50)->get()->reverse()->values();

        return response()->json(['data' => MessageResource::collection($messages)]);
    }

    public function store(StoreMessageRequest $request, Ride $ride): JsonResponse
    {
        $this->authorizeParticipant($request, $ride);

        $otherId = $ride->driver_id === $request->user()->id
            ? $request->input('receiver_id')
            : $ride->driver_id;

        abort_if(! $otherId, 422, 'Informe o usuário destinatário da mensagem.');

        if ($ride->driver_id === $request->user()->id) {
            abort_unless($this->canPassengerMessage($ride, (int) $otherId), 403, 'Este usuário não possui uma solicitação ativa nesta carona.');
        }

        abort_if(
            $request->user()->hasBlocked($otherId) || $request->user()->isBlockedBy($otherId),
            403,
            'Não é possível enviar mensagem para este usuário.',
        );

        $message = $ride->messages()->create([
            'sender_id' => $request->user()->id,
            'receiver_id' => $otherId,
            'body' => $request->body,
        ]);

        return response()->json([
            'message' => 'Mensagem enviada.',
            'chat_message' => new MessageResource($message->load('sender')),
        ], 201);
    }

    public function markRead(Request $request, Message $message): JsonResponse
    {
        abort_if($message->receiver_id !== $request->user()->id, 403, 'Esta mensagem não foi enviada para você.');

        $message->update(['read_at' => now()]);

        return response()->json([
            'message' => 'Mensagem marcada como lida.',
            'chat_message' => new MessageResource($message->refresh()->load('sender')),
        ]);
    }

    private function authorizeParticipant(Request $request, Ride $ride): void
    {
        $isDriver = $ride->driver_id === $request->user()->id;

        $isPassenger = $this->canPassengerMessage($ride, $request->user()->id);

        abort_if(! $isDriver && ! $isPassenger, 403, 'É necessária uma solicitação ativa para conversar com o motorista.');
    }

    private function canPassengerMessage(Ride $ride, int $passengerId): bool
    {
        return RideRequest::where('ride_id', $ride->id)
            ->where('passenger_id', $passengerId)
            ->whereIn('status', [RideRequest::STATUS_PENDING, RideRequest::STATUS_ACCEPTED])
            ->exists() || RidePassenger::where('ride_id', $ride->id)
            ->where('passenger_id', $passengerId)
            ->where('status', RidePassenger::STATUS_CONFIRMED)
            ->exists();
    }
}
