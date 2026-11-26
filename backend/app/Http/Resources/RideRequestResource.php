<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class RideRequestResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'ride_id' => $this->ride_id,
            'ride' => new RideResource($this->whenLoaded('ride')),
            'passenger' => new UserResource($this->whenLoaded('passenger')),
            'status' => $this->status,
            'seats_requested' => $this->seats_requested,
            'message' => $this->message,
            'pickup_lat' => $this->pickup_lat,
            'pickup_lng' => $this->pickup_lng,
            'pickup_label' => $this->pickup_label,
            'responded_at' => $this->responded_at,
            'created_at' => $this->created_at,
        ];
    }
}
