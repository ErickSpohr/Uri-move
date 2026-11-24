<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('rides', function (Blueprint $table) {
            $table->id();
            $table->foreignId('driver_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('vehicle_id')->nullable()->constrained()->nullOnDelete();

            $table->string('origin');
            $table->decimal('origin_lat', 10, 8)->nullable();
            $table->decimal('origin_lng', 11, 8)->nullable();
            $table->string('destination');
            $table->decimal('destination_lat', 10, 8)->nullable();
            $table->decimal('destination_lng', 11, 8)->nullable();

            $table->date('departure_date');
            $table->time('departure_time');

            $table->unsignedInteger('total_seats')->default(4);
            $table->unsignedInteger('available_seats');
            $table->decimal('price', 8, 2)->nullable();
            $table->string('status', 20)->default('scheduled');
            $table->text('notes')->nullable();
            $table->boolean('is_recurring')->default(false);

            $table->timestamps();

            $table->index(['departure_date', 'status']);
            $table->index(['origin', 'destination']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('rides');
    }
};
