<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Fillable(['ride_id', 'latitude', 'longitude', 'accuracy_meters'])]
class RideLocation extends Model
{
    public function ride(): BelongsTo
    {
        return $this->belongsTo(Ride::class);
    }
}
