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
            'origin_lat' => ['nullable', 'required_if:cost_sharing,true,1', 'numeric', 'between:-90,90'],
            'origin_lng' => ['nullable', 'required_if:cost_sharing,true,1', 'numeric', 'between:-180,180'],
            'destination' => ['required', 'string', 'max:191'],
            'destination_lat' => ['nullable', 'required_if:cost_sharing,true,1', 'numeric', 'between:-90,90'],
            'destination_lng' => ['nullable', 'required_if:cost_sharing,true,1', 'numeric', 'between:-180,180'],
            'departure_date' => ['required', 'date_format:Y-m-d', 'after_or_equal:today'],
            'departure_time' => ['required', 'date_format:H:i'],
            'total_seats' => ['required', 'integer', 'min:1', 'max:20'],
            'price' => ['nullable', 'numeric', 'min:0', 'max:9999.99'],
            // Rateio: preço calculado; exige coordenadas de origem e destino.
            'cost_sharing' => ['nullable', 'boolean'],
            'notes' => ['nullable', 'string', 'max:1000'],
            'is_recurring' => ['nullable', 'boolean'],
            'women_only' => ['nullable', 'boolean'],
            // Repetição semanal: dias ISO (1 = segunda … 7 = domingo) até repeat_until (máx. 60 dias).
            'repeat_days' => ['nullable', 'array', 'min:1', 'max:7'],
            'repeat_days.*' => ['integer', 'between:1,7', 'distinct'],
            'repeat_until' => [
                'required_with:repeat_days',
                'nullable',
                'date_format:Y-m-d',
                'after_or_equal:departure_date',
                'before_or_equal:'.now()->addDays(60)->toDateString(),
            ],
        ];
    }

    public function messages(): array
    {
        return [
            'departure_date.after_or_equal' => 'A data de partida não pode estar no passado.',
        ];
    }
}
