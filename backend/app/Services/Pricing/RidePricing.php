<?php

namespace App\Services\Pricing;

use App\Models\Ride;
use App\Models\Vehicle;

/**
 * Preço de carona como rateio de custos (combustível), não como corrida:
 *
 *   custo por km  = preço do litro ÷ consumo do veículo (km/L)
 *   parte fixa    = km da rota × custo por km ÷ (vagas + motorista)
 *   desvio        = km(origem → embarque → destino) − km(origem → destino)
 *   sugerido      = parte fixa + desvio × custo por km   (arredondado para cima a R$ 0,50)
 *
 * O motorista pode reduzir o valor no aceite, nunca aumentar.
 */
class RidePricing
{
    public function __construct(private readonly RouteDistance $routes) {}

    public static function costPerKm(?Vehicle $vehicle): float
    {
        $consumption = (float) ($vehicle?->fuel_consumption ?: config('urimove.default_fuel_consumption'));

        return (float) config('urimove.fuel_price') / max($consumption, 1.0);
    }

    public static function roundUpToHalf(float $value): float
    {
        return ceil(round($value, 4) * 2) / 2;
    }

    public static function baseShare(float $routeKm, float $costPerKm, int $totalSeats): float
    {
        return self::roundUpToHalf($routeKm * $costPerKm / ($totalSeats + 1));
    }

    /**
     * Distância da rota principal (origem → destino) em km.
     */
    public function routeKm(float $originLat, float $originLng, float $destinationLat, float $destinationLng): float
    {
        return round($this->routes->route([[$originLat, $originLng], [$destinationLat, $destinationLng]])['km'], 2);
    }

    /**
     * Orçamento para um passageiro que embarca em (lat, lng).
     *
     * @return array{base_share: float, detour_km: float, detour_minutes: int, detour_cost: float, cost_per_km: float, suggested_price: float, estimated: bool}
     */
    public function quote(Ride $ride, float $lat, float $lng): array
    {
        $costPerKm = (float) $ride->cost_per_km;
        $routeKm = (float) $ride->route_km;
        $base = (float) ($ride->price ?? self::baseShare($routeKm, $costPerKm, $ride->total_seats));

        $withPickup = $this->routes->route([
            [(float) $ride->origin_lat, (float) $ride->origin_lng],
            [$lat, $lng],
            [(float) $ride->destination_lat, (float) $ride->destination_lng],
        ]);
        $direct = $this->routes->route([
            [(float) $ride->origin_lat, (float) $ride->origin_lng],
            [(float) $ride->destination_lat, (float) $ride->destination_lng],
        ]);

        $detourKm = max(0.0, $withPickup['km'] - $direct['km']);
        $detourMinutes = (int) max(0, round($withPickup['minutes'] - $direct['minutes']));
        $detourCost = $detourKm * $costPerKm;

        return [
            'base_share' => $base,
            'detour_km' => round($detourKm, 2),
            'detour_minutes' => $detourMinutes,
            'detour_cost' => round($detourCost, 2),
            'cost_per_km' => round($costPerKm, 3),
            'suggested_price' => self::roundUpToHalf($base + $detourCost),
            'estimated' => $withPickup['estimated'] || $direct['estimated'],
        ];
    }
}
