<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class StoreRideRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'vehicle_id' => ['nullable', 'integer', 'exists:vehicles,id'],
            'origin' => ['required', 'string', 'max:191'],
            'origin_lat' => ['nullable', 'numeric', 'between:-90,90'],
            'origin_lng' => ['nullable', 'numeric', 'between:-180,180'],
            'destination' => ['required', 'string', 'max:191'],
            'destination_lat' => ['nullable', 'numeric', 'between:-90,90'],
            'destination_lng' => ['nullable', 'numeric', 'between:-180,180'],
            'departure_date' => ['required', 'date_format:Y-m-d', 'after_or_equal:today'],
            'departure_time' => ['required', 'date_format:H:i'],
            'total_seats' => ['required', 'integer', 'min:1', 'max:20'],
            'price' => ['nullable', 'numeric', 'min:0', 'max:9999.99'],
            'notes' => ['nullable', 'string', 'max:1000'],
            'is_recurring' => ['nullable', 'boolean'],
        ];
    }

    public function messages(): array
    {
        return [
            'departure_date.after_or_equal' => 'A data de partida não pode estar no passado.',
        ];
    }
}
