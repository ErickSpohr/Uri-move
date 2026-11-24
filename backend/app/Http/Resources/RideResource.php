<?php

namespace App\Http\Resources;

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
            'my_request_status' => $authUser
                ? $this->whenHasRequest($authUser)
                : null,
            'created_at' => $this->created_at,
        ];
    }

    private function whenHasRequest($user): ?string
    {
        if ($this->relationLoaded('requests')) {
            $req = $this->requests->first(fn ($r) => $r->passenger_id === $user->id);

            return $req?->status;
        }

        return optional($this->requests()->where('passenger_id', $user->id)->first())->status;
    }
}
