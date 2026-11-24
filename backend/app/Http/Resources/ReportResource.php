<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ReportResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'reported' => new UserResource($this->whenLoaded('reported')),
            'ride_id' => $this->ride_id,
            'reason' => $this->reason,
            'details' => $this->details,
            'status' => $this->status,
            'created_at' => $this->created_at,
        ];
    }
}
