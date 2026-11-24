<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\CourseResource;
use App\Models\Course;
use Illuminate\Http\Request;

class CourseController extends Controller
{
    public function index(Request $request)
    {
        $query = Course::where('is_active', true);

        if ($request->has('campus_id')) {
            $query->where('campus_id', $request->campus_id);
        }

        return CourseResource::collection($query->orderBy('name')->get());
    }
}
