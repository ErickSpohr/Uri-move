<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('vehicles', function (Blueprint $table) {
            // Consumo médio informado pelo motorista (km por litro).
            $table->decimal('fuel_consumption', 4, 1)->nullable();
        });

        Schema::table('rides', function (Blueprint $table) {
            // Rateio de custos: preço calculado por distância e combustível.
            $table->boolean('cost_sharing')->default(false);
            $table->decimal('route_km', 7, 2)->nullable();
            // Custo por km congelado na publicação (preço do litro ÷ consumo).
            $table->decimal('cost_per_km', 6, 3)->nullable();
        });

        Schema::table('ride_requests', function (Blueprint $table) {
            $table->decimal('detour_km', 6, 2)->nullable();
            $table->unsignedSmallInteger('detour_minutes')->nullable();
            $table->decimal('suggested_price', 8, 2)->nullable();
            // Valor combinado no aceite (≤ sugerido).
            $table->decimal('agreed_price', 8, 2)->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('ride_requests', function (Blueprint $table) {
            $table->dropColumn(['detour_km', 'detour_minutes', 'suggested_price', 'agreed_price']);
        });
        Schema::table('rides', function (Blueprint $table) {
            $table->dropColumn(['cost_sharing', 'route_km', 'cost_per_km']);
        });
        Schema::table('vehicles', function (Blueprint $table) {
            $table->dropColumn('fuel_consumption');
        });
    }
};
