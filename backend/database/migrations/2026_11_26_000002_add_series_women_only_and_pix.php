<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('rides', function (Blueprint $table) {
            // Caronas criadas juntas por repetição semanal compartilham o mesmo series_id.
            $table->uuid('series_id')->nullable()->index();
            $table->boolean('women_only')->default(false);
        });

        Schema::table('users', function (Blueprint $table) {
            $table->string('pix_key', 140)->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('rides', function (Blueprint $table) {
            $table->dropColumn(['series_id', 'women_only']);
        });

        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('pix_key');
        });
    }
};
