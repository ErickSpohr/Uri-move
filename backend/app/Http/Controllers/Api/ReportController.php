<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreReportRequest;
use App\Http\Requests\UpdateReportStatusRequest;
use App\Http\Resources\ReportResource;
use App\Models\Report;
use App\Services\NotificationService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class ReportController extends Controller
{
    public function __construct(private readonly NotificationService $notifications) {}

    public function store(StoreReportRequest $request): JsonResponse
    {
        abort_if($request->user()->id === $request->reported_id, 422, 'Você não pode denunciar a si mesmo.');

        $report = $request->user()->reportsMade()->create($request->validated());

        return response()->json([
            'message' => 'Denúncia registrada. Nossa equipe irá analisar.',
            'report' => new ReportResource($report->refresh()->load(['reported', 'reporter'])),
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

    public function adminIndex(Request $request)
    {
        $filters = $request->validate([
            'status' => ['nullable', Rule::in([
                Report::STATUS_OPEN,
                Report::STATUS_REVIEWING,
                Report::STATUS_RESOLVED,
                Report::STATUS_DISMISSED,
            ])],
        ]);

        $query = Report::with(['reported', 'reporter'])
            ->select('reports.*')
            // Total de denúncias contra o mesmo usuário: ajuda a identificar reincidência.
            ->addSelect([
                'reported_reports_count' => Report::query()
                    ->from('reports as same_user_reports')
                    ->selectRaw('count(*)')
                    ->whereColumn('same_user_reports.reported_id', 'reports.reported_id'),
            ])
            ->latest();

        if (! empty($filters['status'])) {
            $query->where('status', $filters['status']);
        }

        return ReportResource::collection($query->paginate(15));
    }

    public function updateStatus(UpdateReportStatusRequest $request, Report $report): JsonResponse
    {
        $report->update(['status' => $request->status]);

        if (in_array($report->status, [Report::STATUS_RESOLVED, Report::STATUS_DISMISSED], true)) {
            $this->notifications->notifyReportUpdated($report->reporter, $report->status, ['report_id' => $report->id]);
        }

        return response()->json([
            'message' => 'Status da denúncia atualizado.',
            'report' => new ReportResource($report->refresh()->load(['reported', 'reporter'])),
        ]);
    }
}
