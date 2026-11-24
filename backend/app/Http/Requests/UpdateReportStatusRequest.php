<?php

namespace App\Http\Requests;

use App\Models\Report;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateReportStatusRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'status' => ['required', Rule::in([
                Report::STATUS_REVIEWING,
                Report::STATUS_RESOLVED,
                Report::STATUS_DISMISSED,
            ])],
        ];
    }
}
