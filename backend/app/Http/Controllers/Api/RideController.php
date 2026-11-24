<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreRideRequest;
use App\Http\Resources\RideResource;
use App\Models\Ride;
use App\Models\RidePassenger;
use App\Models\Vehicle;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class RideController extends Controller
{
    public function index(Request $request)
    {
        $query = Ride::query()
            ->with(['driver', 'vehicle'])
            ->where('status', '!=', Ride::STATUS_CANCELLED)
            ->where('status', '!=', Ride::STATUS_COMPLETED)
            ->where('departure_date', '>=', $request->date ?? today()->toDateString());

        if ($request->filled('origin')) {
            $query->where('origin', 'ilike', "%{$request->origin}%");
        }

        if ($request->filled('destination')) {
            $query->where('destination', 'ilike', "%{$request->destination}%");
        }

        if ($request->filled('date')) {
            $query->whereDate('departure_date', $request->date);
        }

        if ($request->filled('from_time')) {
            $query->where('departure_time', '>=', $request->from_time);
        }

        if ($request->filled('to_time')) {
            $query->where('departure_time', '<=', $request->to_time);
        }

        if ($request->filled('price_max')) {
            $query->where('price', '<=', (float) $request->price_max);
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

        $ride->update(['status' => Ride::STATUS_CANCELLED]);
        $ride->location()->delete();

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
