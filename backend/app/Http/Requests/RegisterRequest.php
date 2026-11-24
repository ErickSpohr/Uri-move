<?php

namespace App\Http\Requests;

use App\Rules\UriEmailDomain;
use Illuminate\Foundation\Http\FormRequest;

class RegisterRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'name' => ['required', 'string', 'max:191'],
            'email' => ['required', 'string', 'email', 'max:191', 'unique:users,email', new UriEmailDomain],
            'password' => ['required', 'string', 'min:8', 'confirmed'],
            'ra' => ['nullable', 'string', 'max:30', 'unique:users,ra'],
            'phone' => ['nullable', 'string', 'max:30'],
            'gender' => ['nullable', 'string', 'in:woman,man,non_binary,prefer_not_to_say,other'],
            'course_id' => ['nullable', 'integer', 'exists:courses,id'],
            'campus_id' => ['nullable', 'integer', 'exists:campuses,id'],
        ];
    }

    public function messages(): array
    {
        return [
            'email.unique' => 'Este e-mail já está cadastrado.',
            'password.min' => 'A senha deve ter no mínimo :min caracteres.',
            'password.confirmed' => 'A confirmação de senha não confere.',
            'ra.unique' => 'Este RA já está cadastrado.',
        ];
    }
}
