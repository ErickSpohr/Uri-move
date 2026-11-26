<?php

namespace App\Models;

use Carbon\Carbon;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Attributes\Scope;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;

#[Fillable([
    'driver_id', 'vehicle_id', 'origin', 'origin_lat', 'origin_lng',
    'destination', 'destination_lat', 'destination_lng',
    'departure_date', 'departure_time', 'total_seats', 'available_seats',
    'price', 'status', 'notes', 'is_recurring', 'series_id', 'women_only',
])]
class Ride extends Model
{
    use HasFactory;

    public const STATUS_SCHEDULED = 'scheduled';

    public const STATUS_ACTIVE = 'active';

    public const STATUS_COMPLETED = 'completed';

    public const STATUS_CANCELLED = 'cancelled';

    /** Limite de caronas criadas de uma vez por repetição semanal. */
    public const MAX_SERIES_RIDES = 40;

    protected function casts(): array
    {
        return [
            'departure_date' => 'date',
            'total_seats' => 'integer',
            'available_seats' => 'integer',
            'price' => 'decimal:2',
            'is_recurring' => 'boolean',
            'women_only' => 'boolean',
            'origin_lat' => 'decimal:8',
            'origin_lng' => 'decimal:8',
            'destination_lat' => 'decimal:8',
            'destination_lng' => 'decimal:8',
        ];
    }

    public function driver(): BelongsTo
    {
        return $this->belongsTo(User::class, 'driver_id');
    }

    public function vehicle(): BelongsTo
    {
        return $this->belongsTo(Vehicle::class);
    }

    public function requests(): HasMany
    {
        return $this->hasMany(RideRequest::class);
    }

    public function pendingRequests(): HasMany
    {
        return $this->hasMany(RideRequest::class)->where('status', RideRequest::STATUS_PENDING);
    }

    public function passengers(): HasMany
    {
        return $this->hasMany(RidePassenger::class);
    }

    public function messages(): HasMany
    {
        return $this->hasMany(Message::class);
    }

    public function location(): HasOne
    {
        return $this->hasOne(RideLocation::class);
    }

    public function canUseChat(User $user): bool
    {
        if ($this->driver_id === $user->id) {
            return true;
        }

        // Usa a relação pré-carregada por viewerContext() para evitar uma consulta por carona.
        if ($this->relationLoaded('viewerPassengers')) {
            return $this->viewerPassengers->isNotEmpty();
        }

        return $this->passengers()
            ->where('passenger_id', $user->id)
            ->whereIn('status', [RidePassenger::STATUS_CONFIRMED, RidePassenger::STATUS_COMPLETED])
            ->exists();
    }

    /**
     * Solicitações do usuário que está vendo a carona (filtrada no eager load), mais recente primeiro.
     */
    public function viewerRequests(): HasMany
    {
        return $this->hasMany(RideRequest::class)->latest('id');
    }

    /**
     * Participação confirmada/concluída do usuário que está vendo a carona (filtrada no eager load).
     */
    public function viewerPassengers(): HasMany
    {
        return $this->hasMany(RidePassenger::class)
            ->whereIn('status', [RidePassenger::STATUS_CONFIRMED, RidePassenger::STATUS_COMPLETED]);
    }

    /**
     * Pré-carrega o que RideResource precisa sobre o usuário atual (chat e status da solicitação),
     * em duas consultas no total em vez de duas por carona.
     */
    #[Scope]
    protected function viewerContext(Builder $query, ?User $viewer): void
    {
        if (! $viewer) {
            return;
        }

        $query->with([
            'viewerRequests' => fn ($requests) => $requests->where('passenger_id', $viewer->id),
            'viewerPassengers' => fn ($passengers) => $passengers->where('passenger_id', $viewer->id),
        ]);
    }

    public function ratings(): HasMany
    {
        return $this->hasMany(Rating::class);
    }

    public function getOccupiedSeatsAttribute(): int
    {
        return $this->total_seats - $this->available_seats;
    }

    public function getDepartureAttribute(): Carbon
    {
        return Carbon::parse($this->departure_date->toDateString().' '.$this->departure_time);
    }
}
