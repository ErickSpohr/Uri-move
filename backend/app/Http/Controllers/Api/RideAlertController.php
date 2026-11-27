<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\RideAlert;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class RideAlertController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $alerts = RideAlert::query()
            ->where('user_id', $request->user()->id)
            ->where('expires_at', '>', now())
            ->latest()
            ->get();

        return response()->json(['data' => $alerts->map(fn (RideAlert $a) => $this->toArray($a))->values()]);
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'origin' => ['nullable', 'string', 'max:191', 'required_without:destination'],
            'destination' => ['nullable', 'string', 'max:191', 'required_without:origin'],
            'from_time' => ['nullable', 'date_format:H:i'],
            'to_time' => ['nullable', 'date_format:H:i'],
        ], [
            'origin.required_without' => 'Informe a origem ou o destino para criar o aviso.',
            'destination.required_without' => 'Informe a origem ou o destino para criar o aviso.',
        ]);
        $user = $request->user();

        $active = RideAlert::query()->where('user_id', $user->id)->where('expires_at', '>', now());
        abort_if((clone $active)->count() >= RideAlert::MAX_PER_USER, 422, 'Você já tem '.RideAlert::MAX_PER_USER.' avisos ativos. Apague algum para criar outro.');

        // Mesmo aviso repetido: só renova a validade.
        $alert = RideAlert::query()->updateOrCreate(
            [
                'user_id' => $user->id,
                'origin' => $data['origin'] ?? null,
                'destination' => $data['destination'] ?? null,
                'from_time' => $data['from_time'] ?? null,
                'to_time' => $data['to_time'] ?? null,
            ],
            ['expires_at' => now()->addDays(RideAlert::DAYS)],
        );

        return response()->json([
            'message' => 'Pronto! Você será avisado quando aparecer uma carona assim.',
            'alert' => $this->toArray($alert),
        ], 201);
    }

    public function destroy(Request $request, RideAlert $rideAlert): JsonResponse
    {
        abort_if($rideAlert->user_id !== $request->user()->id, 403);
        $rideAlert->delete();

        return response()->json(['message' => 'Aviso removido.']);
    }

    /**
     * @return array<string, mixed>
     */
    private function toArray(RideAlert $alert): array
    {
        return [
            'id' => $alert->id,
            'origin' => $alert->origin,
            'destination' => $alert->destination,
            'from_time' => $alert->from_time ? substr($alert->from_time, 0, 5) : null,
            'to_time' => $alert->to_time ? substr($alert->to_time, 0, 5) : null,
            'expires_at' => $alert->expires_at?->toIso8601String(),
        ];
    }
}
