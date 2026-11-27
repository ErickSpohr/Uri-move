<?php

namespace App\Services;

use App\Models\Ride;
use App\Models\RideAlert;
use App\Models\User;
use Carbon\Carbon;

/**
 * Avisa quem salvou um alerta compatível quando uma carona é publicada.
 * Uma notificação por alerta por publicação (uma série semanal conta como uma).
 */
class RideAlertService
{
    public function __construct(private readonly NotificationService $notifications) {}

    public function notifyMatches(Ride $ride, User $driver): void
    {
        if ($ride->available_seats < 1) {
            return;
        }

        // Bloqueio em qualquer direção: ninguém é avisado sobre quem bloqueou/foi bloqueado.
        $blocked = $driver->blocksGiven()->pluck('blocked_id')
            ->merge($driver->blocksReceived()->pluck('blocker_id'));

        $alerts = RideAlert::query()
            ->with('user')
            ->where('expires_at', '>', now())
            ->where('user_id', '!=', $driver->id)
            ->whereNotIn('user_id', $blocked)
            ->get()
            ->filter(fn (RideAlert $alert) => $alert->matches($ride))
            // Caronas só para mulheres: só avisa usuárias.
            ->filter(fn (RideAlert $alert) => ! $ride->women_only || $alert->user?->isWoman())
            ->unique('user_id');

        $date = Carbon::parse($ride->departure_date)->format('d/m');
        $time = substr((string) $ride->departure_time, 0, 5);

        foreach ($alerts as $alert) {
            $this->notifications->send(
                $alert->user,
                'ride_alert',
                'Carona encontrada',
                "{$ride->origin} → {$ride->destination} em {$date} às {$time}.",
                $driver,
                ['ride_id' => $ride->id, 'alert_id' => $alert->id],
            );
        }
    }
}
