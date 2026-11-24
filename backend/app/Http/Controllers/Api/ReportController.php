<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreReportRequest;
use App\Http\Requests\UpdateReportStatusRequest;
use App\Http\Resources\ReportResource;
use App\Models\Report;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ReportController extends Controller
{
    public function store(StoreReportRequest $request): JsonResponse
    {
        abort_if($request->user()->id === $request->reported_id, 422, 'Você não pode denunciar a si mesmo.');

        $report = $request->user()->reportsMade()->create($request->validated());

        return response()->json([
            'message' => 'Denúncia registrada. Nossa equipe irá analisar.',
            'report' => new ReportResource($report->refresh()->load(['reported'])),
        ], 201);
    }

    public function mine(Request $request): JsonResponse
    {
        $reports = $request->user()->reportsMade()
            ->with(['reported'])
            ->orderByDesc('created_at')
            ->paginate(15);

        return response()->json(ReportResource::collection($reports));
    }

    public function adminIndex(Request $request): JsonResponse
    {
        $query = Report::with(['reported', 'reporter'])->latest();

        if ($request->filled('status')) {
            $query->where('status', $request->status);
        }

        return response()->json(ReportResource::collection($query->paginate(15)));
    }

    public function updateStatus(UpdateReportStatusRequest $request, Report $report): JsonResponse
    {
        $report->update(['status' => $request->status]);

        return response()->json([
            'message' => 'Status da denúncia atualizado.',
            'report' => new ReportResource($report->refresh()->load(['reported'])),
        ]);
    }
}
