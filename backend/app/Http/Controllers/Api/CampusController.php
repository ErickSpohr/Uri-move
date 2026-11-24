<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\CampusResource;
use App\Models\Campus;
use Illuminate\Http\Request;

class CampusController extends Controller
{
    public function index(Request $request)
    {
        $query = Campus::where('is_active', true);

        if ($request->has('city')) {
            $query->where('city', 'like', "%{$request->city}%");
        }

        return CampusResource::collection($query->orderBy('name')->get());
    }
}
