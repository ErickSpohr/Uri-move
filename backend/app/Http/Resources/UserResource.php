<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class UserResource extends JsonResource
{
    /** Inclui e-mail, telefone, RA e gênero mesmo sem usuário autenticado na requisição (login/verificação). */
    private bool $forOwner = false;

    /**
     * Recurso do próprio usuário (respostas de login, verificação e perfil).
     */
    public static function owner(mixed $resource): static
    {
        $instance = new static($resource);
        $instance->forOwner = true;

        return $instance;
    }

    public function toArray(Request $request): array
    {
        // Contato, RA e dados pessoais só para o próprio usuário e para administradores.
        $viewer = $request->user();
        $canSeePrivate = $this->forOwner || ($viewer && ($viewer->id === $this->id || $viewer->isAdmin()));

        return [
            'id' => $this->id,
            'name' => $this->name,
            'email' => $this->when($canSeePrivate, $this->email),
            'phone' => $this->when($canSeePrivate, $this->phone),
            'gender' => $this->when($canSeePrivate, $this->gender),
            'pix_key' => $this->when($canSeePrivate, $this->pix_key),
            'ra' => $this->when($canSeePrivate, $this->ra),
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
