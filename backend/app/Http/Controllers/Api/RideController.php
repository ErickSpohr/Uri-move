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
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class RideController extends Controller
{
    public function __construct(private readonly NotificationService $notifications) {}

    public function index(Request $request)
    {
        $filters = $request->validate([
            'origin' => ['nullable', 'string', 'max:191'],
            'destination' => ['nullable', 'string', 'max:191'],
            'date' => ['nullable', 'date_format:Y-m-d'],
            'from_time' => ['nullable', 'date_format:H:i'],
            'to_time' => ['nullable', 'date_format:H:i'],
            'price_max' => ['nullable', 'numeric', 'min:0'],
        ]);
        $viewer = $request->user();

        $query = Ride::query()
            ->with(['driver', 'vehicle'])
            ->viewerContext($viewer)
            ->whereNotIn('status', [Ride::STATUS_CANCELLED, Ride::STATUS_COMPLETED])
            ->where('departure_date', '>=', $filters['date'] ?? today()->toDateString())
            // Caronas de quem o usuário bloqueou ou de quem o bloqueou não aparecem na busca.
            ->whereNotIn('driver_id', $viewer->blocksGiven()->select('blocked_id'))
            ->whereNotIn('driver_id', Block::query()->where('blocked_id', $viewer->id)->select('blocker_id'));

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

        if (isset($filters['price_max'])) {
            $query->where('price', '<=', (float) $filters['price_max']);
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

        $data = $request->validated();
        $data['driver_id'] = $request->user()->id;
        $data['available_seats'] = $data['total_seats'];

        $ride = Ride::create($data);

        return response()->json([
            'message' => 'Carona publicada com sucesso.',
            'ride' => new RideResource($ride->load(['driver', 'vehicle'])),
        ], 201);
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

        return response()->json([
            'message' => 'Carona cancelada.',
            'ride' => new RideResource($ride->load(['driver', 'vehicle'])),
        ]);
    }

    private function increaseDriverRideCount(Ride $ride): void
    {
        $ride->driver()->increment('ride_count');
    }
}
