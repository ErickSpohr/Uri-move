<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\RespondRideRequestRequest;
use App\Http\Requests\StoreRideRequestRequest;
use App\Http\Resources\RideRequestResource;
use App\Models\Ride;
use App\Models\RidePassenger;
use App\Models\RideRequest;
use App\Services\NotificationService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class RideRequestController extends Controller
{
    public function __construct(private readonly NotificationService $notifications) {}

    public function index(Request $request, Ride $ride): JsonResponse
    {
        $this->authorizeRideDriver($request, $ride);

        $requests = $ride->requests()
            ->with(['passenger'])
            ->orderByDesc('created_at')
            ->paginate(15);

        return response()->json(RideRequestResource::collection($requests));
    }

    public function store(StoreRideRequestRequest $request, Ride $ride): JsonResponse
    {
        abort_if($ride->driver_id === $request->user()->id, 422, 'Você não pode solicitar a sua própria carona.');
        abort_if($ride->status !== Ride::STATUS_SCHEDULED, 422, 'A carona não está disponível para solicitação.');
        abort_if(
            $request->user()->hasBlocked($ride->driver_id) || $request->user()->isBlockedBy($ride->driver_id),
            403,
            'Não é possível solicitar esta carona.',
        );

        $hasActiveRequest = $ride->requests()
            ->where('passenger_id', $request->user()->id)
            ->whereIn('status', [RideRequest::STATUS_PENDING, RideRequest::STATUS_ACCEPTED])
            ->exists();

        abort_if($hasActiveRequest, 422, 'Você já possui uma solicitação ativa para esta carona.');

        $seats = $request->filled('seats_requested') ? (int) $request->seats_requested : 1;

        abort_if($seats > $ride->available_seats, 422, 'Não há vagas suficientes nesta carona.');

        $rideRequest = $ride->requests()->create([
            'passenger_id' => $request->user()->id,
            'status' => RideRequest::STATUS_PENDING,
            'seats_requested' => $seats,
            'message' => $request->message,
        ]);

        $this->notifications->notifyRideRequestSubmitted($ride->driver, $request->user(), [
            'ride_id' => $ride->id,
            'request_id' => $rideRequest->id,
        ]);

        return response()->json([
            'message' => 'Solicitação enviada. Aguarde a confirmação do motorista.',
            'request' => new RideRequestResource($rideRequest->load(['passenger', 'ride'])),
        ], 201);
    }

    public function respond(RespondRideRequestRequest $request, Ride $ride, RideRequest $rideRequest): JsonResponse
    {
        $this->authorizeRideDriver($request, $ride);
        abort_if($rideRequest->ride_id !== $ride->id, 404, 'Solicitação não encontrada nesta carona.');
        abort_if($rideRequest->status !== RideRequest::STATUS_PENDING, 422, 'Essa solicitação já foi respondida.');

        $action = $request->action;

        if ($action === RideRequest::STATUS_ACCEPTED) {
            $this->accept($ride, $rideRequest);
        } else {
            $this->reject($ride, $rideRequest);
        }

        return response()->json([
            'message' => 'Solicitação '.($action === RideRequest::STATUS_ACCEPTED ? 'aceita' : 'recusada').'.',
            'request' => new RideRequestResource($rideRequest->refresh()->load(['passenger', 'ride'])),
        ]);
    }

    public function destroy(Request $request, Ride $ride, RideRequest $rideRequest): JsonResponse
    {
        abort_if($rideRequest->ride_id !== $ride->id, 404, 'Solicitação não encontrada nesta carona.');
        abort_if($rideRequest->passenger_id !== $request->user()->id, 403, 'Você não pode cancelar esta solicitação.');
        abort_if(in_array($rideRequest->status, [RideRequest::STATUS_REJECTED, RideRequest::STATUS_CANCELLED], true), 422, 'Esta solicitação não pode mais ser cancelada.');
        // Vaga confirmada só pode ser liberada antes da partida; depois disso a participação vale para avaliações.
        abort_if(
            $rideRequest->status === RideRequest::STATUS_ACCEPTED && $ride->status !== Ride::STATUS_SCHEDULED,
            422,
            'A carona já começou ou terminou; não é possível cancelar a vaga.',
        );

        DB::transaction(function () use ($ride, $rideRequest) {
            $wasAccepted = $rideRequest->status === RideRequest::STATUS_ACCEPTED;
            $rideRequest->update(['status' => RideRequest::STATUS_CANCELLED]);

            if ($wasAccepted) {
                RidePassenger::where('ride_id', $ride->id)
                    ->where('passenger_id', $rideRequest->passenger_id)
                    ->update(['status' => RidePassenger::STATUS_CANCELLED]);

                $ride->increment('available_seats', $rideRequest->seats_requested);
            }
        });

        return response()->json(['message' => 'Solicitação cancelada.']);
    }

    private function accept(Ride $ride, RideRequest $rideRequest): void
    {
        DB::transaction(function () use ($ride, $rideRequest) {
            // Bloqueia carona e solicitação até o commit: aceitações simultâneas são serializadas
            // e a verificação de vagas/status usa valores atuais do banco.
            $ride = Ride::whereKey($ride->id)->lockForUpdate()->firstOrFail();
            $rideRequest = RideRequest::whereKey($rideRequest->id)->lockForUpdate()->firstOrFail();

            abort_if($rideRequest->status !== RideRequest::STATUS_PENDING, 422, 'Essa solicitação já foi respondida.');
            abort_if($rideRequest->seats_requested > $ride->available_seats, 422, 'Não há vagas suficientes para aceitar esta solicitação.');

            $rideRequest->update([
                'status' => RideRequest::STATUS_ACCEPTED,
                'responded_at' => now(),
            ]);

            RidePassenger::updateOrCreate(
                ['ride_id' => $ride->id, 'passenger_id' => $rideRequest->passenger_id],
                ['status' => RidePassenger::STATUS_CONFIRMED],
            );

            $ride->decrement('available_seats', $rideRequest->seats_requested);

            $this->notifications->notifyRideRequestAccepted($rideRequest->passenger, $ride->driver, [
                'ride_id' => $ride->id,
                'request_id' => $rideRequest->id,
            ]);
        });
    }

    private function reject(Ride $ride, RideRequest $rideRequest): void
    {
        $rideRequest->update([
            'status' => RideRequest::STATUS_REJECTED,
            'responded_at' => now(),
        ]);

        $this->notifications->notifyRideRequestRejected($rideRequest->passenger, $ride->driver, [
            'ride_id' => $ride->id,
            'request_id' => $rideRequest->id,
        ]);
    }
}
