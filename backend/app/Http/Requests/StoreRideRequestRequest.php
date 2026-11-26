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
            'pickup_lat' => ['nullable', 'numeric', 'between:-90,90', 'required_with:pickup_lng'],
            'pickup_lng' => ['nullable', 'numeric', 'between:-180,180', 'required_with:pickup_lat'],
            'pickup_label' => ['nullable', 'string', 'max:191'],
        ];
    }
}
