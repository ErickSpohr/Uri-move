<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class FavoriteRouteResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'origin' => $this->origin,
            'origin_lat' => $this->origin_lat ? (float) $this->origin_lat : null,
            'origin_lng' => $this->origin_lng ? (float) $this->origin_lng : null,
            'destination' => $this->destination,
            'destination_lat' => $this->destination_lat ? (float) $this->destination_lat : null,
            'destination_lng' => $this->destination_lng ? (float) $this->destination_lng : null,
            'created_at' => $this->created_at,
        ];
    }
}
