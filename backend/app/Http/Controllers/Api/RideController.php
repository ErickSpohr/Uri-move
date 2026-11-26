<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreRideRequest;
use App\Http\Resources\RideResource;
use App\Models\Block;
use App\Models\Ride;
use App\Models\RidePassenger;
use App\Models\RideRequest;
use App\Models\Vehicle;
use App\Services\NotificationService;
use App\Services\Pricing\RidePricing;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class RideController extends Controller
{
    public function __construct(
        private readonly NotificationService $notifications,
        private readonly RidePricing $pricing,
    ) {}

    /**
     * Orçamento do rateio para um ponto de embarque (prévia antes de pedir a vaga).
     */
    public function quote(Request $request, Ride $ride): JsonResponse
    {
        $data = $request->validate([
            'pickup_lat' => ['required', 'numeric', 'between:-90,90'],
            'pickup_lng' => ['required', 'numeric', 'between:-180,180'],
        ]);
        abort_unless($ride->cost_sharing && $ride->route_km, 422, 'Esta carona não usa preço calculado.');

        return response()->json(['data' => $this->pricing->quote($ride, (float) $data['pickup_lat'], (float) $data['pickup_lng'])]);
    }

    public function index(Request $request)
    {
        $filters = $request->validate([
            'origin' => ['nullable', 'string', 'max:191'],
            'destination' => ['nullable', 'string', 'max:191'],
            'date' => ['nullable', 'date_format:Y-m-d'],
            'from_time' => ['nullable', 'date_format:H:i'],
            'to_time' => ['nullable', 'date_format:H:i'],
            'price_max' => ['nullable', 'numeric', 'min:0'],
            'women_only' => ['nullable', 'boolean'],
        ]);
        $viewer = $request->user();

        $query = Ride::query()
            ->with(['driver', 'vehicle'])
            ->viewerContext($viewer)
            ->whereNotIn('status', [Ride::STATUS_CANCELLED, Ride::STATUS_COMPLETED])
            ->where('departure_date', '>=', $filters['date'] ?? today()->toDateString());

        // Rota pública: o filtro de bloqueio só se aplica a quem está logado.
        if ($viewer) {
            // Caronas de quem o usuário bloqueou ou de quem o bloqueou não aparecem na busca.
            $query->whereNotIn('driver_id', $viewer->blocksGiven()->select('blocked_id'))
                ->whereNotIn('driver_id', Block::query()->where('blocked_id', $viewer->id)->select('blocker_id'));
        }

        if (! empty($filters['origin'])) {
            $query->where('origin', 'ilike', '%'.$filters['origin'].'%');
        }

        if (! empty($filters['destination'])) {
            $query->where('destination', 'ilike', '%'.$filters['destination'].'%');
        }

        if (! empty($filters['date'])) {
            $query->whereDate('departure_date', $filters['date']);
        }

        if (! empty($filters['from_time'])) {
            $query->where('departure_time', '>=', $filters['from_time']);
        }

        if (! empty($filters['to_time'])) {
            $query->where('departure_time', '<=', $filters['to_time']);
        }

        // Caronas exclusivas para mulheres só aparecem para quem se identifica como mulher.
        if (! $viewer?->isWoman()) {
            $query->where('women_only', false);
        } elseif ($request->boolean('women_only')) {
            $query->where('women_only', true);
        }

        if (isset($filters['price_max'])) {
            // Preço nulo significa carona gratuita e satisfaz qualquer limite.
            $query->where(fn ($q) => $q->whereNull('price')->orWhere('price', '<=', (float) $filters['price_max']));
        }

        $rides = $query
            ->where('available_seats', '>', 0)
            ->withCount('pendingRequests')
            ->orderBy('departure_date')
            ->orderBy('departure_time')
            ->paginate(15);

        return RideResource::collection($rides);
    }

    public function store(StoreRideRequest $request): JsonResponse
    {
        if ($request->filled('vehicle_id')) {
            $vehicle = Vehicle::findOrFail($request->vehicle_id);
            abort_if($vehicle->user_id !== $request->user()->id, 403, 'Você não possui este veículo.');
        }

        $data = $request->safe()->except(['repeat_days', 'repeat_until']);
        $data['women_only'] = (bool) ($data['women_only'] ?? false);
        abort_if(
            $data['women_only'] && ! $request->user()->isWoman(),
            422,
            'Somente motoristas que se identificam como mulher podem oferecer caronas exclusivas para mulheres. Ajuste o gênero no seu perfil.',
        );

        $data['driver_id'] = $request->user()->id;
        $data['available_seats'] = $data['total_seats'];
        $data['cost_sharing'] = (bool) ($data['cost_sharing'] ?? false);

        if ($data['cost_sharing']) {
            // Preço exibido ("a partir de") = parte fixa do rateio; o desvio entra por passageiro.
            $data['route_km'] = $this->pricing->routeKm(
                (float) $data['origin_lat'], (float) $data['origin_lng'],
                (float) $data['destination_lat'], (float) $data['destination_lng'],
            );
            $data['cost_per_km'] = RidePricing::costPerKm(isset($vehicle) ? $vehicle : null);
            $data['price'] = RidePricing::baseShare($data['route_km'], $data['cost_per_km'], $data['total_seats']);
        }

        $dates = $this->seriesDates(
            $data['departure_date'],
            $request->input('repeat_days', []),
            $request->input('repeat_until'),
        );

        if (count($dates) > 1) {
            $data['series_id'] = (string) Str::uuid();
            $data['is_recurring'] = true;
        }

        $rides = DB::transaction(fn () => collect($dates)->map(
            fn (string $date) => Ride::create(['departure_date' => $date] + $data),
        ));
        $ride = $rides->first();

        return response()->json([
            'message' => $rides->count() > 1
                ? "{$rides->count()} caronas publicadas."
                : 'Carona publicada com sucesso.',
            'ride' => new RideResource($ride->load(['driver', 'vehicle'])),
            'rides_created' => $rides->count(),
        ], 201);
    }

    /**
     * Datas da carona: a data inicial e, se houver repetição, cada dia da semana escolhido até o limite.
     *
     * @param  list<int>  $weekdays  Dias ISO (1 = segunda … 7 = domingo).
     * @return list<string>
     */
    private function seriesDates(string $start, array $weekdays, ?string $until): array
    {
        $dates = [$start];

        if ($weekdays === [] || ! $until) {
            return $dates;
        }

        $weekdays = array_map('intval', $weekdays);
        $day = Carbon::parse($start)->addDay();
        $end = Carbon::parse($until);

        while ($day->lte($end) && count($dates) < Ride::MAX_SERIES_RIDES) {
            if (in_array($day->dayOfWeekIso, $weekdays, true)) {
                $dates[] = $day->toDateString();
            }
            $day->addDay();
        }

        return $dates;
    }

    public function show(Request $request, Ride $ride): RideResource
    {
        $ride->load(['driver', 'vehicle']);
        $ride->setRelation('viewerRequests', $ride->viewerRequests()->where('passenger_id', $request->user()->id)->get());

        if ($ride->driver_id === $request->user()->id) {
            $ride->loadCount('pendingRequests');
        }

        return new RideResource($ride);
    }

    public function start(Request $request, Ride $ride): JsonResponse
    {
        $this->authorizeRideDriver($request, $ride);

        abort_if($ride->status !== Ride::STATUS_SCHEDULED, 422, 'A carona não está agendada.');

        $ride->update(['status' => Ride::STATUS_ACTIVE]);

        return response()->json([
            'message' => 'Carona iniciada.',
            'ride' => new RideResource($ride->load(['driver', 'vehicle'])),
        ]);
    }

    public function complete(Request $request, Ride $ride): JsonResponse
    {
        $this->authorizeRideDriver($request, $ride);

        abort_if($ride->status === Ride::STATUS_COMPLETED, 422, 'A carona já foi concluída.');
        abort_if($ride->status === Ride::STATUS_CANCELLED, 422, 'A carona foi cancelada.');

        $ride->passengers()
            ->where('status', RidePassenger::STATUS_CONFIRMED)
            ->update(['status' => RidePassenger::STATUS_COMPLETED]);

        $ride->update(['status' => Ride::STATUS_COMPLETED]);
        $ride->location()->delete();

        $this->increaseDriverRideCount($ride);

        return response()->json([
            'message' => 'Carona concluída.',
            'ride' => new RideResource($ride->load(['driver', 'vehicle'])),
        ]);
    }

    public function cancel(Request $request, Ride $ride): JsonResponse
    {
        $this->authorizeRideDriver($request, $ride);

        abort_if(in_array($ride->status, [Ride::STATUS_COMPLETED, Ride::STATUS_CANCELLED], true), 422, 'A carona não pode mais ser cancelada.');

        // scope=series cancela também as próximas caronas agendadas da mesma repetição.
        $rides = collect([$ride]);
        if ($request->input('scope') === 'series' && $ride->series_id) {
            $rides = $rides->merge(
                Ride::where('series_id', $ride->series_id)
                    ->where('driver_id', $ride->driver_id)
                    ->where('id', '!=', $ride->id)
                    ->where('status', Ride::STATUS_SCHEDULED)
                    ->where('departure_date', '>=', $ride->departure_date)
                    ->get()
            );
        }

        foreach ($rides as $target) {
            $this->cancelSingle($request, $target);
        }

        return response()->json([
            'message' => $rides->count() > 1 ? "{$rides->count()} caronas canceladas." : 'Carona cancelada.',
            'cancelled_count' => $rides->count(),
            'ride' => new RideResource($ride->refresh()->load(['driver', 'vehicle'])),
        ]);
    }

    /**
     * Cancela a carona, encerra solicitações e participações e avisa os passageiros afetados.
     */
    private function cancelSingle(Request $request, Ride $ride): void
    {
        $affectedPassengers = DB::transaction(function () use ($ride) {
            $requests = $ride->requests()
                ->with('passenger')
                ->whereIn('status', [RideRequest::STATUS_PENDING, RideRequest::STATUS_ACCEPTED])
                ->get();

            $ride->requests()
                ->whereIn('id', $requests->pluck('id'))
                ->update(['status' => RideRequest::STATUS_CANCELLED, 'responded_at' => now()]);
            $ride->passengers()
                ->where('status', RidePassenger::STATUS_CONFIRMED)
                ->update(['status' => RidePassenger::STATUS_CANCELLED]);
            $ride->update(['status' => Ride::STATUS_CANCELLED]);
            $ride->location()->delete();

            return $requests->pluck('passenger')->filter()->unique('id');
        });

        foreach ($affectedPassengers as $passenger) {
            $this->notifications->notifyRideCancelled($passenger, $request->user(), ['ride_id' => $ride->id]);
        }
    }

    private function increaseDriverRideCount(Ride $ride): void
    {
        $ride->driver()->increment('ride_count');
    }
}
