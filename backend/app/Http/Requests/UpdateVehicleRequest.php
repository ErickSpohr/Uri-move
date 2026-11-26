<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateVehicleRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'brand' => ['nullable', 'string', 'max:60'],
            'model' => ['nullable', 'string', 'max:60'],
            'color' => ['nullable', 'string', 'max:40'],
            'plate' => ['nullable', 'string', 'max:10', Rule::unique('vehicles', 'plate')->ignore($this->vehicle->id)],
            'year' => ['nullable', 'integer', 'between:1900,'.(date('Y') + 1)],
            'seats' => ['nullable', 'integer', 'between:1,20'],
            'fuel_consumption' => ['nullable', 'numeric', 'between:3,40'],
            'is_active' => ['nullable', 'boolean'],
        ];
    }
}
