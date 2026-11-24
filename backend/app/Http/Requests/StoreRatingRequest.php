<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class StoreRatingRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'ride_id' => ['required', 'integer', 'exists:rides,id'],
            'rated_id' => ['required', 'integer', 'exists:users,id'],
            'score' => ['required', 'integer', 'between:1,5'],
            'punctuality' => ['nullable', 'integer', 'between:1,5'],
            'communication' => ['nullable', 'integer', 'between:1,5'],
            'safety' => ['nullable', 'integer', 'between:1,5'],
            'driving' => ['nullable', 'integer', 'between:1,5'],
            'behavior' => ['nullable', 'integer', 'between:1,5'],
            'comment' => ['nullable', 'string', 'max:1000'],
        ];
    }
}
