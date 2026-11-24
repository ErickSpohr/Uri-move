<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreVehicleRequest;
use App\Http\Requests\UpdateVehicleRequest;
use App\Http\Resources\VehicleResource;
use App\Models\Vehicle;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class VehicleController extends Controller
{
    public function index(Request $request)
    {
        return VehicleResource::collection($request->user()->vehicles()->orderByDesc('id')->get());
    }

    public function store(StoreVehicleRequest $request): JsonResponse
    {
        $vehicle = $request->user()->vehicles()->create($request->validated());

        return response()->json([
            'message' => 'Veículo cadastrado.',
            'vehicle' => new VehicleResource($vehicle),
        ], 201);
    }

    public function update(UpdateVehicleRequest $request, Vehicle $vehicle): JsonResponse
    {
        $this->authorizeVehicle($request, $vehicle);

        $vehicle->update($request->validated());

        return response()->json([
            'message' => 'Veículo atualizado.',
            'vehicle' => new VehicleResource($vehicle->refresh()),
        ]);
    }

    public function destroy(Request $request, Vehicle $vehicle): JsonResponse
    {
        $this->authorizeVehicle($request, $vehicle);

        $vehicle->delete();

        return response()->json(['message' => 'Veículo removido.']);
    }

    private function authorizeVehicle(Request $request, Vehicle $vehicle): void
    {
        abort_if($vehicle->user_id !== $request->user()->id, 403, 'Você não possui este veículo.');
    }
}
