<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class StoreRideRequestRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'seats_requested' => ['nullable', 'integer', 'min:1', 'max:10'],
            'message' => ['nullable', 'string', 'max:1000'],
        ];
    }
}
