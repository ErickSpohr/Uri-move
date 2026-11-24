<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('ratings', function (Blueprint $table) {
            $table->id();
            $table->foreignId('ride_id')->constrained()->cascadeOnDelete();
            $table->foreignId('rater_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('rated_id')->constrained('users')->cascadeOnDelete();
            $table->unsignedTinyInteger('score')->default(5);
            $table->unsignedTinyInteger('punctuality')->nullable();
            $table->unsignedTinyInteger('communication')->nullable();
            $table->unsignedTinyInteger('safety')->nullable();
            $table->unsignedTinyInteger('driving')->nullable();
            $table->unsignedTinyInteger('behavior')->nullable();
            $table->text('comment')->nullable();
            $table->timestamps();

            $table->unique(['ride_id', 'rater_id', 'rated_id']);
            $table->index(['rated_id', 'created_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('ratings');
    }
};
