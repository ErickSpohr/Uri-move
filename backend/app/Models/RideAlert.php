<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Fillable(['user_id', 'origin', 'destination', 'from_time', 'to_time', 'expires_at'])]
class RideAlert extends Model
{
    /** Validade do alerta, em dias. */
    public const DAYS = 30;

    /** Alertas ativos por usuário. */
    public const MAX_PER_USER = 10;

    protected function casts(): array
    {
        return ['expires_at' => 'datetime'];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    /**
     * Texto sem acentos e em minúsculas, para comparar "Santo Angelo" com "Santo Ângelo".
     */
    public static function normalize(?string $value): string
    {
        $ascii = iconv('UTF-8', 'ASCII//TRANSLIT//IGNORE', (string) $value);

        return trim(mb_strtolower($ascii === false ? (string) $value : $ascii));
    }

    /**
     * A carona combina com o alerta? Origem/destino: o texto do alerta contido no da carona
     * (como na busca); horário: dentro da faixa, quando informada.
     */
    public function matches(Ride $ride): bool
    {
        foreach (['origin', 'destination'] as $field) {
            $wanted = self::normalize($this->{$field});
            if ($wanted !== '' && ! str_contains(self::normalize($ride->{$field}), $wanted)) {
                return false;
            }
        }

        $time = substr((string) $ride->departure_time, 0, 5);
        if ($this->from_time && $time < substr($this->from_time, 0, 5)) {
            return false;
        }
        if ($this->to_time && $time > substr($this->to_time, 0, 5)) {
            return false;
        }

        return true;
    }
}
