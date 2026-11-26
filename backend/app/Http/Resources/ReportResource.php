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
            'reporter' => new UserResource($this->whenLoaded('reporter')),
            'reported_reports_count' => $this->when(
                isset($this->reported_reports_count),
                fn () => (int) $this->reported_reports_count,
            ),
            'ride_id' => $this->ride_id,
            'reason' => $this->reason,
            'details' => $this->details,
            'status' => $this->status,
            'created_at' => $this->created_at,
            'updated_at' => $this->updated_at,
        ];
    }
}
