<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('ride_requests', function (Blueprint $table) {
            $table->id();
            $table->foreignId('ride_id')->constrained()->cascadeOnDelete();
            $table->foreignId('passenger_id')->constrained('users')->cascadeOnDelete();
            $table->string('status', 20)->default('pending');
            $table->unsignedInteger('seats_requested')->default(1);
            $table->text('message')->nullable();
            $table->timestamp('responded_at')->nullable();
            $table->timestamps();

            $table->index(['ride_id', 'status']);
            $table->index(['passenger_id', 'status']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('ride_requests');
    }
};
