<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateProfileRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'name' => ['nullable', 'string', 'max:191'],
            'phone' => ['nullable', 'string', 'max:30'],
            'gender' => ['nullable', 'string', 'in:woman,man,non_binary,prefer_not_to_say,other'],
            'ra' => ['nullable', 'string', 'max:30', Rule::unique('users', 'ra')->ignore($this->user()->id)],
            'course_id' => ['nullable', 'integer', 'exists:courses,id'],
            'campus_id' => ['nullable', 'integer', 'exists:campuses,id'],
            'photo' => ['nullable', 'image', 'mimes:jpeg,png,jpg,webp', 'max:2048'],
        ];
    }
}
