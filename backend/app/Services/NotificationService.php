<?php

namespace App\Services;

use App\Models\User;
use App\Models\UserNotification;

class NotificationService
{
    public function send(
        User $user,
        string $type,
        string $title,
        ?string $body = null,
        ?User $actor = null,
        array $payload = [],
    ): UserNotification {
        return $user->notifications()->create([
            'actor_id' => $actor?->id,
            'type' => $type,
            'title' => $title,
            'body' => $body,
            'payload' => $payload,
        ]);
    }

    public function notifyRideRequestSubmitted(User $driver, User $passenger, array $payload = []): void
    {
        $this->send(
            $driver,
            'ride_request_received',
            'Nova solicitação de carona',
            "{$passenger->name} solicitou uma vaga na sua carona.",
            $passenger,
            $payload,
        );
    }

    public function notifyRideRequestAccepted(User $passenger, User $driver, array $payload = []): void
    {
        $this->send(
            $passenger,
            'ride_request_accepted',
            'Solicitação aceita',
            "{$driver->name} aceitou sua solicitação de carona.",
            $driver,
            $payload,
        );
    }

    public function notifyRideRequestRejected(User $passenger, User $driver, array $payload = []): void
    {
        $this->send(
            $passenger,
            'ride_request_rejected',
            'Solicitação recusada',
            "{$driver->name} recusou sua solicitação de carona.",
            $driver,
            $payload,
        );
    }

    public function notifyRatingReceived(User $rated, User $rater, array $payload = []): void
    {
        $this->send(
            $rated,
            'rating_received',
            'Nova avaliação',
            "{$rater->name} avaliou você.",
            $rater,
            $payload,
        );
    }

    public function notifyRideCancelled(User $passenger, User $driver, array $payload = []): void
    {
        $this->send(
            $passenger,
            'ride_cancelled',
            'Carona cancelada',
            "{$driver->name} cancelou a carona em que você estava.",
            $driver,
            $payload,
        );
    }
}
