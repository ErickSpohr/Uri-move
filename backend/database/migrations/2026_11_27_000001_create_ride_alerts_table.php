<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // "Me avise quando aparecer": busca salva que gera notificação ao publicar carona compatível.
        Schema::create('ride_alerts', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('origin', 191)->nullable();
            $table->string('destination', 191)->nullable();
            $table->time('from_time')->nullable();
            $table->time('to_time')->nullable();
            $table->timestamp('expires_at');
            $table->timestamps();
            $table->index(['expires_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('ride_alerts');
    }
};
