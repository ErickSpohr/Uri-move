<?php

namespace App\Http\Resources;

use App\Models\RideRequest;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class RideResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $authUser = $request->user();
        $occupied = $this->total_seats - $this->available_seats;

        return [
            'id' => $this->id,
            'can_chat' => $authUser ? $this->resource->canUseChat($authUser) : false,
            'driver' => new UserResource($this->whenLoaded('driver')),
            'vehicle' => new VehicleResource($this->whenLoaded('vehicle')),
            'origin' => $this->origin,
            'origin_lat' => $this->origin_lat ? (float) $this->origin_lat : null,
            'origin_lng' => $this->origin_lng ? (float) $this->origin_lng : null,
            'destination' => $this->destination,
            'destination_lat' => $this->destination_lat ? (float) $this->destination_lat : null,
            'destination_lng' => $this->destination_lng ? (float) $this->destination_lng : null,
            'departure_date' => $this->departure_date?->format('Y-m-d'),
            'departure_time' => $this->departure_time,
            'departure_at' => $this->departure->toIso8601String(),
            'total_seats' => $this->total_seats,
            'available_seats' => $this->available_seats,
            'occupied_seats' => $occupied,
            'price' => $this->price ? (float) $this->price : null,
            'status' => $this->status,
            'notes' => $this->notes,
            'is_recurring' => $this->is_recurring,
            'my_request_status' => $authUser ? $this->viewerRequest($authUser)?->status : null,
            'my_request_id' => $authUser ? $this->viewerRequest($authUser)?->id : null,
            // Valor do passageiro: combinado no aceite ou, antes disso, o sugerido.
            'my_price' => $authUser
                ? ($this->viewerRequest($authUser)?->agreed_price ?? $this->viewerRequest($authUser)?->suggested_price)
                : null,
            'cost_sharing' => (bool) $this->cost_sharing,
            'route_km' => $this->route_km,
            'series_id' => $this->series_id,
            'women_only' => (bool) $this->women_only,
            // Chave Pix do motorista só para quem tem vaga confirmada (ou o próprio motorista).
            'driver_pix_key' => $this->when(
                $authUser && $this->relationLoaded('driver') && $this->driver?->pix_key
                    && ($authUser->id === $this->driver_id || $this->resource->canUseChat($authUser)),
                fn () => $this->driver->pix_key,
            ),
            'created_at' => $this->created_at,
        ];
    }

    private ?RideRequest $viewerRequestCache = null;

    private bool $viewerRequestResolved = false;

    /**
     * Solicitação mais recente do usuário nesta carona (consultada uma única vez por recurso).
     */
    private function viewerRequest(User $user): ?RideRequest
    {
        if (! $this->viewerRequestResolved) {
            $this->viewerRequestCache = $this->relationLoaded('viewerRequests')
                ? $this->viewerRequests->first(fn ($r) => $r->passenger_id === $user->id)
                : $this->requests()->where('passenger_id', $user->id)->latest('id')->first();
            $this->viewerRequestResolved = true;
        }

        return $this->viewerRequestCache;
    }
}
