<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Fillable(['reporter_id', 'reported_id', 'ride_id', 'reason', 'details', 'status'])]
class Report extends Model
{
    use HasFactory;

    public const REASONS = [
        'misconduct', 'harassment', 'dangerous_driving',
        'fraud', 'fake_profile', 'other',
    ];

    public const STATUS_OPEN = 'open';

    public const STATUS_REVIEWING = 'reviewing';

    public const STATUS_RESOLVED = 'resolved';

    public const STATUS_DISMISSED = 'dismissed';

    protected function casts(): array
    {
        return ['status' => 'string'];
    }

    public function reporter(): BelongsTo
    {
        return $this->belongsTo(User::class, 'reporter_id');
    }

    public function reported(): BelongsTo
    {
        return $this->belongsTo(User::class, 'reported_id');
    }

    public function ride(): BelongsTo
    {
        return $this->belongsTo(Ride::class);
    }
}
