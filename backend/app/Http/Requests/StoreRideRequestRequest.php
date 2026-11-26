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
            // O motorista decide se aceita sabendo de onde o passageiro sai.
            'pickup_lat' => ['required', 'numeric', 'between:-90,90'],
            'pickup_lng' => ['required', 'numeric', 'between:-180,180'],
            'pickup_label' => ['nullable', 'string', 'max:191'],
        ];
    }

    /**
     * @return array<string, string>
     */
    public function messages(): array
    {
        return [
            'pickup_lat.required' => 'Marque no mapa o ponto onde você vai embarcar.',
            'pickup_lng.required' => 'Marque no mapa o ponto onde você vai embarcar.',
        ];
    }
}
