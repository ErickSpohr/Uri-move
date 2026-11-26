<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class StoreVehicleRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'brand' => ['required', 'string', 'max:60'],
            'model' => ['required', 'string', 'max:60'],
            'color' => ['nullable', 'string', 'max:40'],
            'plate' => ['required', 'string', 'max:10', 'unique:vehicles,plate'],
            'year' => ['nullable', 'integer', 'between:1900,'.(date('Y') + 1)],
            'seats' => ['nullable', 'integer', 'between:1,20'],
            'fuel_consumption' => ['nullable', 'numeric', 'between:3,40'],
        ];
    }
}
