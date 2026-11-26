<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

/**
 * Edição de carona publicada (só antes de algum passageiro ser aceito).
 */
class UpdateRideRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'departure_date' => ['sometimes', 'date_format:Y-m-d', 'after_or_equal:today'],
            'departure_time' => ['sometimes', 'date_format:H:i'],
            'total_seats' => ['sometimes', 'integer', 'min:1', 'max:20'],
            'notes' => ['sometimes', 'nullable', 'string', 'max:1000'],
        ];
    }
}
