<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Ride;
use App\Models\RideLocation;
use App\Models\RideRequest;
use App\Services\PickupProximityService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class RideLocationController extends Controller
{
    public function show(Request $request, Ride $ride): JsonResponse
    {
        abort_unless($ride->canUseChat($request->user()), 403, 'Somente participantes confirmados podem acompanhar a carona.');
        abort_unless($ride->status === Ride::STATUS_ACTIVE, 422, 'O rastreamento só está disponível durante a carona.');

        $location = $ride->location;
        $current = $location && $location->updated_at->greaterThan(now()->subSeconds(30));

        return response()->json(['data' => [
            'sharing' => $current,
            'latitude' => $current ? (float) $location->latitude : null,
            'longitude' => $current ? (float) $location->longitude : null,
            'accuracy_meters' => $current ? $location->accuracy_meters : null,
            'updated_at' => $current ? $location->updated_at->toIso8601String() : null,
            'destination_lat' => $ride->destination_lat ? (float) $ride->destination_lat : null,
            'destination_lng' => $ride->destination_lng ? (float) $ride->destination_lng : null,
            'stops' => $this->stops($request, $ride),
        ]]);
    }

    /**
     * Pontos de encontro dos passageiros aceitos: o motorista vê todos; o passageiro, só o seu.
     *
     * @return list<array<string, mixed>>
     */
    private function stops(Request $request, Ride $ride): array
    {
        $viewer = $request->user();

        return $ride->requests()
            ->with('passenger')
            ->where('status', RideRequest::STATUS_ACCEPTED)
            ->whereNotNull('pickup_lat')
            ->when($ride->driver_id !== $viewer->id, fn ($q) => $q->where('passenger_id', $viewer->id))
            ->get()
            ->map(fn (RideRequest $r) => [
                'request_id' => $r->id,
                'passenger_id' => $r->passenger_id,
                'passenger_name' => $r->passenger?->name,
                'latitude' => $r->pickup_lat,
                'longitude' => $r->pickup_lng,
                'label' => $r->pickup_label,
                'picked_up' => $r->arrived_notified_at !== null,
            ])
            ->values()
            ->all();
    }

    public function update(Request $request, Ride $ride, PickupProximityService $proximity): JsonResponse
    {
        $this->authorizeRideDriver($request, $ride);
        abort_unless($ride->status === Ride::STATUS_ACTIVE, 422, 'Inicie a carona antes de compartilhar sua localização.');

        $data = $request->validate([
            'latitude' => ['required', 'numeric', 'between:-90,90'],
            'longitude' => ['required', 'numeric', 'between:-180,180'],
            'accuracy_meters' => ['nullable', 'integer', 'between:0,10000'],
        ]);
        RideLocation::updateOrCreate(['ride_id' => $ride->id], $data)->touch();
        $proximity->check($ride, (float) $data['latitude'], (float) $data['longitude']);

        return response()->json(['message' => 'Localização atualizada.']);
    }

    public function destroy(Request $request, Ride $ride): JsonResponse
    {
        $this->authorizeRideDriver($request, $ride);
        $ride->location()->delete();

        return response()->json(['message' => 'Compartilhamento interrompido.']);
    }
}
