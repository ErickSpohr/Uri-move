<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class RatingResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'ride_id' => $this->ride_id,
            'rater' => new UserResource($this->whenLoaded('rater')),
            'score' => $this->score,
            'punctuality' => $this->punctuality,
            'communication' => $this->communication,
            'safety' => $this->safety,
            'driving' => $this->driving,
            'behavior' => $this->behavior,
            'comment' => $this->comment,
            'created_at' => $this->created_at,
        ];
    }
}
