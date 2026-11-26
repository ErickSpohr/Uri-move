<?php

namespace App\Services;

use App\Models\Ride;
use App\Models\RideRequest;

/**
 * Avisa passageiros quando o motorista se aproxima do ponto de encontro.
 * Cada aviso é enviado uma única vez por solicitação.
 */
class PickupProximityService
{
    /** Distância (m) considerada "a cerca de 5 minutos" em trânsito urbano. */
    public const NEAR_METERS = 2000;

    /** Distância (m) considerada chegada ao ponto de encontro. */
    public const ARRIVED_METERS = 150;

    public function __construct(private readonly NotificationService $notifications) {}

    public function check(Ride $ride, float $latitude, float $longitude): void
    {
        $requests = $ride->requests()
            ->with('passenger')
            ->where('status', RideRequest::STATUS_ACCEPTED)
            ->whereNotNull('pickup_lat')
            ->whereNull('arrived_notified_at')
            ->get();

        foreach ($requests as $rideRequest) {
            $distance = self::distanceMeters($latitude, $longitude, $rideRequest->pickup_lat, $rideRequest->pickup_lng);
            $payload = ['ride_id' => $ride->id, 'request_id' => $rideRequest->id];

            if ($distance <= self::ARRIVED_METERS) {
                $rideRequest->update(['arrived_notified_at' => now(), 'near_notified_at' => $rideRequest->near_notified_at ?? now()]);
                $this->notifications->send($rideRequest->passenger, 'driver_arrived', 'Motorista chegou',
                    "{$ride->driver->name} chegou ao ponto de encontro.", $ride->driver, $payload);
            } elseif ($distance <= self::NEAR_METERS && $rideRequest->near_notified_at === null) {
                $rideRequest->update(['near_notified_at' => now()]);
                $this->notifications->send($rideRequest->passenger, 'driver_near', 'Motorista a caminho',
                    "{$ride->driver->name} está a cerca de 5 minutos do ponto de encontro.", $ride->driver, $payload);
            }
        }
    }

    /**
     * Distância geodésica pela fórmula de haversine (raio médio da Terra: 6 371 km).
     */
    public static function distanceMeters(float $lat1, float $lng1, float $lat2, float $lng2): float
    {
        $dLat = deg2rad($lat2 - $lat1);
        $dLng = deg2rad($lng2 - $lng1);
        $a = sin($dLat / 2) ** 2 + cos(deg2rad($lat1)) * cos(deg2rad($lat2)) * sin($dLng / 2) ** 2;

        return 6371000 * 2 * atan2(sqrt($a), sqrt(1 - $a));
    }
}
