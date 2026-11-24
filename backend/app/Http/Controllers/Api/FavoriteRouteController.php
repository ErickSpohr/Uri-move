<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreFavoriteRouteRequest;
use App\Http\Resources\FavoriteRouteResource;
use App\Models\FavoriteRoute;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class FavoriteRouteController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $routes = $request->user()->favoriteRoutes()->orderByDesc('id')->get();

        return response()->json(FavoriteRouteResource::collection($routes));
    }

    public function store(StoreFavoriteRouteRequest $request): JsonResponse
    {
        $route = $request->user()->favoriteRoutes()->create($request->validated());

        return response()->json([
            'message' => 'Rota salva.',
            'route' => new FavoriteRouteResource($route),
        ], 201);
    }

    public function destroy(Request $request, FavoriteRoute $favoriteRoute): JsonResponse
    {
        abort_if($favoriteRoute->user_id !== $request->user()->id, 403, 'Esta rota não é sua.');

        $favoriteRoute->delete();

        return response()->json(['message' => 'Rota removida.']);
    }
}
