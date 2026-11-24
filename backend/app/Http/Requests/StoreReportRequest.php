<?php

namespace App\Http\Requests;

use App\Models\Report;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreReportRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'reported_id' => ['required', 'integer', 'exists:users,id'],
            'ride_id' => ['nullable', 'integer', 'exists:rides,id'],
            'reason' => ['required', Rule::in(Report::REASONS)],
            'details' => ['nullable', 'string', 'max:2000'],
        ];
    }
}
