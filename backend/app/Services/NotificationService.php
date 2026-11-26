<?php

namespace App\Services;

use App\Models\Report;
use App\Models\User;
use App\Models\UserNotification;
use App\Services\Fcm\FcmSender;
use App\Services\WebPush\WebPushSender;

use function Illuminate\Support\defer;

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
        $notification = $user->notifications()->create([
            'actor_id' => $actor?->id,
            'type' => $type,
            'title' => $title,
            'body' => $body,
            'payload' => $payload,
        ]);

        // Push para navegadores (Web Push) e para o app Android (FCM),
        // executado após o envio da resposta HTTP.
        $data = [
            'type' => $type,
            'notification_id' => $notification->id,
            'ride_id' => $payload['ride_id'] ?? null,
        ];
        defer(function () use ($user, $title, $body, $data) {
            app(WebPushSender::class)->sendToUser($user, ['title' => $title, 'body' => $body] + $data);
            app(FcmSender::class)->sendToUser($user, $title, $body, $data);
        });

        return $notification;
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

    /**
     * Avisa quem denunciou que a análise terminou (sem revelar a medida tomada).
     */
    public function notifyReportUpdated(User $reporter, string $status, array $payload = []): void
    {
        $message = $status === Report::STATUS_RESOLVED
            ? 'Sua denúncia foi analisada e as medidas cabíveis foram tomadas.'
            : 'Sua denúncia foi analisada e encerrada.';

        $this->send($reporter, 'report_update', 'Denúncia analisada', $message, null, $payload + ['status' => $status]);
    }
}
