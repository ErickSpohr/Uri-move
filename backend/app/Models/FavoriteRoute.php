<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Fillable(['user_id', 'origin', 'destination', 'origin_lat', 'origin_lng', 'destination_lat', 'destination_lng'])]
class FavoriteRoute extends Model
{
    use HasFactory;

    protected function casts(): array
    {
        return [
            'origin_lat' => 'decimal:8',
            'origin_lng' => 'decimal:8',
            'destination_lat' => 'decimal:8',
            'destination_lng' => 'decimal:8',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
