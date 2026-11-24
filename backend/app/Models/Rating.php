<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Fillable(['ride_id', 'rater_id', 'rated_id', 'score', 'punctuality', 'communication', 'safety', 'driving', 'behavior', 'comment'])]
class Rating extends Model
{
    use HasFactory;

    protected function casts(): array
    {
        return [
            'score' => 'integer',
            'punctuality' => 'integer',
            'communication' => 'integer',
            'safety' => 'integer',
            'driving' => 'integer',
            'behavior' => 'integer',
        ];
    }

    public function ride(): BelongsTo
    {
        return $this->belongsTo(Ride::class);
    }

    public function rater(): BelongsTo
    {
        return $this->belongsTo(User::class, 'rater_id');
    }

    public function rated(): BelongsTo
    {
        return $this->belongsTo(User::class, 'rated_id');
    }
}
