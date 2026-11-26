<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreMessageRequest;
use App\Models\Ride;
use App\Models\RideChatMessage;
use App\Models\RideChatRead;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class RideChatController extends Controller
{
    public function index(Request $request, Ride $ride): JsonResponse
    {
        abort_unless($ride->canUseChat($request->user()), 403, 'Somente participantes confirmados podem acessar o chat.');
        $data = $request->validate([
            'after_id' => ['nullable', 'integer', 'min:0'],
            'before_id' => ['nullable', 'integer', 'min:1', 'prohibits:after_id'],
        ]);
        $query = RideChatMessage::where('ride_id', $ride->id)->with('sender:id,name');
        if (isset($data['after_id'])) {
            $messages = $query->where('id', '>', $data['after_id'])->orderBy('id')->limit(50)->get();
        } else {
            if (isset($data['before_id'])) {
                $query->where('id', '<', $data['before_id']);
            }
            $messages = $query->orderByDesc('id')->limit(50)->get()->reverse()->values();
        }

        if ($messages->isNotEmpty()) {
            RideChatRead::markRead($ride->id, $request->user()->id, (int) $messages->max('id'));
        }

        return response()->json(['data' => $messages]);
    }

    public function store(StoreMessageRequest $request, Ride $ride): JsonResponse
    {
        abort_unless($ride->canUseChat($request->user()), 403, 'Somente participantes confirmados podem acessar o chat.');
        abort_if(in_array($ride->status, [Ride::STATUS_CANCELLED, Ride::STATUS_COMPLETED], true), 422, 'Esta carona foi encerrada. O chat está disponível apenas para leitura.');
        $message = RideChatMessage::create([
            'ride_id' => $ride->id,
            'sender_id' => $request->user()->id,
            'body' => $request->validated('body'),
        ]);

        return response()->json(['data' => $message->load('sender:id,name')], 201);
    }
}
