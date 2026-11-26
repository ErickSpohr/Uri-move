<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Última mensagem do chat em grupo da carona vista por um participante.
 */
#[Fillable(['ride_id', 'user_id', 'last_read_message_id'])]
class RideChatRead extends Model
{
    protected function casts(): array
    {
        return ['last_read_message_id' => 'integer'];
    }

    public function ride(): BelongsTo
    {
        return $this->belongsTo(Ride::class);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    /**
     * Avança o marcador de leitura; nunca retrocede (ex.: carregamento de mensagens antigas).
     */
    public static function markRead(int $rideId, int $userId, int $messageId): void
    {
        $read = static::firstOrNew(['ride_id' => $rideId, 'user_id' => $userId]);

        if ($messageId > (int) $read->last_read_message_id) {
            $read->last_read_message_id = $messageId;
            $read->save();
        }
    }
}
