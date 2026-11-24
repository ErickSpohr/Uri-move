<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class UserNotificationResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'type' => $this->type,
            'actor' => new UserResource($this->whenLoaded('actor')),
            'title' => $this->title,
            'body' => $this->body,
            'payload' => $this->payload,
            'is_read' => $this->isRead(),
            'read_at' => $this->read_at,
            'created_at' => $this->created_at,
        ];
    }
}
