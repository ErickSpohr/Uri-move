<?php

namespace App\Services\Pricing;

use App\Services\PickupProximityService;
use Illuminate\Support\Facades\Http;
use Throwable;

/**
 * Distância e tempo de carro entre pontos, pelo OSRM (OpenStreetMap).
 * Se o serviço falhar, estima pela distância em linha reta × 1,3 a 50 km/h.
 */
class RouteDistance
{
    private const OSRM = 'https://router.project-osrm.org/route/v1/driving/';

    /**
     * @param  list<array{0: float, 1: float}>  $points  [latitude, longitude] na ordem do trajeto
     * @return array{km: float, minutes: float, estimated: bool}
     */
    public function route(array $points): array
    {
        $path = implode(';', array_map(fn ($p) => $p[1].','.$p[0], $points));

        try {
            $response = Http::timeout(6)->get(self::OSRM.$path, ['overview' => 'false']);
            if ($response->successful() && $response->json('code') === 'Ok') {
                return [
                    'km' => $response->json('routes.0.distance') / 1000,
                    'minutes' => $response->json('routes.0.duration') / 60,
                    'estimated' => false,
                ];
            }
        } catch (Throwable) {
            // Cai na estimativa abaixo.
        }

        $meters = 0.0;
        for ($i = 1; $i < count($points); $i++) {
            $meters += PickupProximityService::distanceMeters($points[$i - 1][0], $points[$i - 1][1], $points[$i][0], $points[$i][1]);
        }
        $km = $meters / 1000 * 1.3;

        return ['km' => $km, 'minutes' => $km / 50 * 60, 'estimated' => true];
    }
}
