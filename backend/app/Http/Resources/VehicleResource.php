<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class VehicleResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'brand' => $this->brand,
            'model' => $this->model,
            'color' => $this->color,
            'plate' => $this->plate,
            'year' => $this->year,
            'seats' => $this->seats,
            'is_active' => $this->is_active,
        ];
    }
}
