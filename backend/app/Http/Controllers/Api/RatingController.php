<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreRatingRequest;
use App\Http\Resources\RatingResource;
use App\Http\Resources\UserResource;
use App\Models\Rating;
use App\Models\Ride;
use App\Models\RidePassenger;
use App\Models\User;
use App\Services\NotificationService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class RatingController extends Controller
{
    public function __construct(private readonly NotificationService $notifications) {}

    public function store(StoreRatingRequest $request): JsonResponse
    {
        $ride = Ride::findOrFail($request->ride_id);
        $rated = User::findOrFail($request->rated_id);

        abort_if($request->user()->id === $rated->id, 422, 'Você não pode avaliar a si mesmo.');
        abort_if($ride->status !== Ride::STATUS_COMPLETED, 422, 'Avaliações só são permitidas após a conclusão da carona.');

        $this->assertParticipation($request->user(), $ride);
        $this->assertSameRideParticipants($request->user(), $rated, $ride);

        $alreadyRated = Rating::where('ride_id', $ride->id)
            ->where('rater_id', $request->user()->id)
            ->where('rated_id', $rated->id)
            ->exists();

        abort_if($alreadyRated, 422, 'Você já avaliou este usuário nesta carona.');

        $rating = DB::transaction(function () use ($request, $ride, $rated) {
            $rating = Rating::create([
                'ride_id' => $ride->id,
                'rater_id' => $request->user()->id,
                'rated_id' => $rated->id,
                'score' => $request->score,
                'punctuality' => $request->punctuality,
                'communication' => $request->communication,
                'safety' => $request->safety,
                'driving' => $request->driving,
                'behavior' => $request->behavior,
                'comment' => $request->comment,
            ]);

            $this->recalculateUserRating($rated);

            return $rating;
        });

        $this->notifications->notifyRatingReceived($rated, $request->user(), [
            'ride_id' => $ride->id,
            'rating_id' => $rating->id,
        ]);

        return response()->json([
            'message' => 'Avaliação registrada.',
            'rating' => new RatingResource($rating),
        ], 201);
    }

    public function userRatings(Request $request, int $userId): JsonResponse
    {
        $ratings = Rating::with(['rater'])
            ->where('rated_id', $userId)
            ->orderByDesc('created_at')
            ->paginate(15);

        return response()->json(RatingResource::collection($ratings));
    }

    /**
     * Participantes da carona (exceto o próprio usuário), indicando quem ele já avaliou.
     */
    public function participants(Request $request, Ride $ride): JsonResponse
    {
        $user = $request->user();
        $this->assertParticipation($user, $ride);

        $passengerIds = RidePassenger::where('ride_id', $ride->id)
            ->whereIn('status', [RidePassenger::STATUS_CONFIRMED, RidePassenger::STATUS_COMPLETED])
            ->pluck('passenger_id');

        $participants = User::with(['course', 'campus'])
            ->whereIn('id', $passengerIds->push($ride->driver_id)->unique())
            ->where('id', '!=', $user->id)
            ->get();

        $ratedIds = Rating::where('ride_id', $ride->id)
            ->where('rater_id', $user->id)
            ->pluck('rated_id')
            ->all();

        return response()->json([
            'can_rate' => $ride->status === Ride::STATUS_COMPLETED,
            'data' => $participants->map(fn (User $participant) => [
                'user' => new UserResource($participant),
                'role' => $participant->id === $ride->driver_id ? 'driver' : 'passenger',
                'already_rated' => in_array($participant->id, $ratedIds, true),
            ])->values(),
        ]);
    }

    private function assertParticipation(User $user, Ride $ride): void
    {
        $isDriver = $ride->driver_id === $user->id;
        $isPassenger = RidePassenger::where('ride_id', $ride->id)
            ->where('passenger_id', $user->id)
            ->whereIn('status', [RidePassenger::STATUS_CONFIRMED, RidePassenger::STATUS_COMPLETED])
            ->exists();

        abort_if(! $isDriver && ! $isPassenger, 403, 'Você não participou desta carona.');
    }

    private function assertSameRideParticipants(User $rater, User $rated, Ride $ride): void
    {
        $isDriver = $ride->driver_id === $rated->id;
        $isPassenger = RidePassenger::where('ride_id', $ride->id)
            ->where('passenger_id', $rated->id)
            ->whereIn('status', [RidePassenger::STATUS_CONFIRMED, RidePassenger::STATUS_COMPLETED])
            ->exists();

        abort_if(! $isDriver && ! $isPassenger, 422, 'O usuário avaliado não participou desta carona.');
    }

    private function recalculateUserRating(User $user): void
    {
        $aggregates = $user->ratingsReceived()
            ->selectRaw('count(*) as count, avg(score) as avg')
            ->first();

        $user->update([
            'rating_count' => (int) $aggregates->count,
            'rating_avg' => $aggregates->avg ? round((float) $aggregates->avg, 2) : null,
        ]);
    }
}
