<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('ride_requests', function (Blueprint $table) {
            $table->decimal('pickup_lat', 10, 7)->nullable();
            $table->decimal('pickup_lng', 10, 7)->nullable();
            $table->string('pickup_label', 191)->nullable();
            // Controle dos avisos de aproximação enviados durante a carona.
            $table->timestamp('near_notified_at')->nullable();
            $table->timestamp('arrived_notified_at')->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('ride_requests', function (Blueprint $table) {
            $table->dropColumn(['pickup_lat', 'pickup_lng', 'pickup_label', 'near_notified_at', 'arrived_notified_at']);
        });
    }
};
