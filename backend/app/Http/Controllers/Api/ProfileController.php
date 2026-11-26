<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\UpdateProfileRequest;
use App\Http\Resources\RideRequestResource;
use App\Http\Resources\RideResource;
use App\Http\Resources\UserResource;
use App\Models\Ride;
use App\Models\RidePassenger;
use App\Models\RideRequest;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Response;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class ProfileController extends Controller
{
    public function me(Request $request)
    {
        return UserResource::owner($request->user()->load('course', 'campus'));
    }

    public function update(UpdateProfileRequest $request): JsonResponse
    {
        $user = $request->user();
        $data = $request->safe()->except(['photo']);

        DB::transaction(function () use ($request, $user, $data): void {
            if ($request->hasFile('photo')) {
                $photo = $request->file('photo');
                DB::table('user_photos')->updateOrInsert(
                    ['user_id' => $user->id],
                    [
                        'mime_type' => $photo->getMimeType(),
                        'contents' => base64_encode($photo->getContent()),
                    ]
                );
                $data['photo_path'] = 'database:'.Str::random(12);
            }

            $user->update($data);
        });

        return response()->json([
            'message' => 'Perfil atualizado.',
            'user' => UserResource::owner($user->refresh()->load('course', 'campus')),
        ]);
    }

    public function photo(User $user): Response
    {
        $photo = DB::table('user_photos')->where('user_id', $user->id)->first();
        abort_if($photo === null, 404);

        return response(base64_decode($photo->contents), 200, [
            'Content-Type' => $photo->mime_type,
            'Cache-Control' => 'public, max-age=300',
            'Access-Control-Allow-Origin' => '*',
        ]);
    }

    public function show(Request $request, int $id): JsonResponse
    {
        $user = User::with(['course', 'campus'])->findOrFail($id);

        return response()->json([
            'user' => new UserResource($user),
        ]);
    }

    public function myRides(Request $request)
    {
        $rides = $request->user()->drives()
            ->with(['driver', 'vehicle'])
            ->viewerContext($request->user())
            // Mais recentes primeiro (publicadas por último no topo).
            ->orderByDesc('created_at')
            ->orderByDesc('id')
            ->paginate(15);

        return RideResource::collection($rides);
    }

    public function joinedRides(Request $request)
    {
        $rides = Ride::with(['driver', 'vehicle'])
            ->viewerContext($request->user())
            ->whereIn('id', $request->user()->ridePassengers()
                ->whereIn('status', [RidePassenger::STATUS_CONFIRMED, RidePassenger::STATUS_COMPLETED])
                ->select('ride_id'))
            ->where('status', '!=', Ride::STATUS_CANCELLED)
            ->orderByDesc('created_at')
            ->orderByDesc('id')
            ->paginate(15);

        return RideResource::collection($rides);
    }

    public function myRequests(Request $request)
    {
        $viewer = $request->user();
        $requests = RideRequest::with([
            'ride' => fn ($ride) => $ride->viewerContext($viewer),
            'ride.driver',
            'ride.vehicle',
        ])
            ->where('passenger_id', $request->user()->id)
            ->orderByDesc('created_at')
            ->paginate(15);

        return RideRequestResource::collection($requests);
    }
}
