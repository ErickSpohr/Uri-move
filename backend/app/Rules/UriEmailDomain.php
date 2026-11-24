<?php

namespace App\Rules;

use Closure;
use Illuminate\Contracts\Validation\ValidationRule;

class UriEmailDomain implements ValidationRule
{
    public function validate(string $attribute, mixed $value, Closure $fail): void
    {
        $value = mb_strtolower(trim((string) $value));

        if (! filter_var($value, FILTER_VALIDATE_EMAIL)) {
            $fail('O campo e-mail deve ser um endereço de e-mail válido.');

            return;
        }

        $domains = array_map('strtolower', config('urimove.allowlist_email_domains', []));

        $isAllowed = collect($domains)->contains(fn (string $domain) => str_ends_with($value, '@'.$domain));

        if (! $isAllowed) {
            $fail('Somente é permitido o cadastro com e-mail institucional da URI.');
        }
    }
}
