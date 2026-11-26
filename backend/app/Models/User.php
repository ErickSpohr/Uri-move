<?php

namespace App\Models;

use Database\Factories\UserFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Attributes\Hidden;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

#[Fillable(['name', 'email', 'password', 'phone', 'gender', 'photo_path', 'ra', 'course_id', 'campus_id', 'role', 'rating_avg', 'rating_count', 'pix_key'])]
#[Hidden(['password', 'remember_token'])]
class User extends Authenticatable
{
    /** @use HasFactory<UserFactory> */
    use HasApiTokens, HasFactory, Notifiable;

    public const ROLE_STUDENT = 'student';

    public const ROLE_TEACHER = 'teacher';

    public const ROLE_STAFF = 'staff';

    public const ROLE_ADMIN = 'admin';

    public const GENDER_WOMAN = 'woman';

    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'password' => 'hashed',
            'rating_avg' => 'decimal:2',
            'is_active' => 'boolean',
        ];
    }

    public function getPhotoUrlAttribute(): ?string
    {
        if (! $this->photo_path) {
            return null;
        }

        if (str_starts_with($this->photo_path, 'database:')) {
            return url('/api/v1/users/'.$this->id.'/photo').'?v='.substr($this->photo_path, 9);
        }

        return asset('storage/'.$this->photo_path);
    }

    public function campus(): BelongsTo
    {
        return $this->belongsTo(Campus::class);
    }

    public function course(): BelongsTo
    {
        return $this->belongsTo(Course::class);
    }

    public function vehicles(): HasMany
    {
        return $this->hasMany(Vehicle::class);
    }

    public function drives(): HasMany
    {
        return $this->hasMany(Ride::class, 'driver_id');
    }

    public function rideRequests(): HasMany
    {
        return $this->hasMany(RideRequest::class, 'passenger_id');
    }

    public function ridePassengers(): HasMany
    {
        return $this->hasMany(RidePassenger::class, 'passenger_id');
    }

    public function messagesSent(): HasMany
    {
        return $this->hasMany(Message::class, 'sender_id');
    }

    public function messagesReceived(): HasMany
    {
        return $this->hasMany(Message::class, 'receiver_id');
    }

    public function ratingsGiven(): HasMany
    {
        return $this->hasMany(Rating::class, 'rater_id');
    }

    public function ratingsReceived(): HasMany
    {
        return $this->hasMany(Rating::class, 'rated_id');
    }

    public function notifications(): HasMany
    {
        return $this->hasMany(UserNotification::class);
    }

    public function reportsMade(): HasMany
    {
        return $this->hasMany(Report::class, 'reporter_id');
    }

    public function reportsReceived(): HasMany
    {
        return $this->hasMany(Report::class, 'reported_id');
    }

    public function favoriteRoutes(): HasMany
    {
        return $this->hasMany(FavoriteRoute::class);
    }

    public function blocksGiven(): HasMany
    {
        return $this->hasMany(Block::class, 'blocker_id');
    }

    public function blocksReceived(): HasMany
    {
        return $this->hasMany(Block::class, 'blocked_id');
    }

    public function emailVerifications(): HasMany
    {
        return $this->hasMany(EmailVerification::class);
    }

    public function hasBlocked(User|int $other): bool
    {
        $id = $other instanceof User ? $other->id : $other;

        return $this->blocksGiven()->where('blocked_id', $id)->exists();
    }

    public function isBlockedBy(User|int $other): bool
    {
        $id = $other instanceof User ? $other->id : $other;

        return Block::query()
            ->where('blocker_id', $id)
            ->where('blocked_id', $this->id)
            ->exists();
    }

    public function isWoman(): bool
    {
        return $this->gender === self::GENDER_WOMAN;
    }

    public function isAdmin(): bool
    {
        return $this->role === self::ROLE_ADMIN;
    }

    public function isVerified(): bool
    {
        return ! is_null($this->email_verified_at);
    }
}
