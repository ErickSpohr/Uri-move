<?php

namespace App\Http\Requests;

use App\Models\RideRequest;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class RespondRideRequestRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'action' => ['required', Rule::in([RideRequest::STATUS_ACCEPTED, RideRequest::STATUS_REJECTED])],
        ];
    }
}
