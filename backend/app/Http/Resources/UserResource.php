<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class UserResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'email' => $this->email,
            'phone' => $this->phone,
            'gender' => $this->gender,
            'ra' => $this->ra,
            'role' => $this->role,
            'photo_url' => $this->photo_url,
            'is_verified' => $this->isVerified(),
            'rating_avg' => $this->rating_avg ? (float) $this->rating_avg : null,
            'rating_count' => $this->rating_count,
            'ride_count' => $this->ride_count,
            'course' => new CourseResource($this->whenLoaded('course')),
            'campus' => new CampusResource($this->whenLoaded('campus')),
            'created_at' => $this->created_at,
        ];
    }
}
