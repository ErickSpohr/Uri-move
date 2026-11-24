<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreBlockRequest;
use App\Http\Resources\UserResource;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class BlockController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $blocked = $request->user()->blocksGiven()
            ->with('blocked')
            ->latest()
            ->get()
            ->pluck('blocked');

        return response()->json(UserResource::collection($blocked));
    }

    public function store(StoreBlockRequest $request): JsonResponse
    {
        $blocked = User::findOrFail($request->blocked_id);

        abort_if($request->user()->id === $blocked->id, 422, 'Você não pode bloquear a si mesmo.');

        $block = $request->user()->blocksGiven()->firstOrCreate(['blocked_id' => $blocked->id]);

        return response()->json([
            'message' => 'Usuário bloqueado.',
            'blocked_user' => new UserResource($block->blocked->load('course', 'campus')),
        ], 201);
    }

    public function destroy(Request $request): JsonResponse
    {
        $deleted = $request->user()->blocksGiven()
            ->where('blocked_id', $request->user_id)
            ->delete();

        abort_if(! $deleted, 404, 'Este usuário não está na sua lista de bloqueados.');

        return response()->json(['message' => 'Usuário desbloqueado.']);
    }
}
