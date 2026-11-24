<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ProfilePhotoTest extends TestCase
{
    use RefreshDatabase;

    public function test_user_can_change_name_and_photo(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);
        $photo = UploadedFile::fake()->image('perfil.jpg', 160, 160);

        $response = $this->post('/api/v1/me', [
            '_method' => 'PUT',
            'name' => 'Nome Atualizado',
            'photo' => $photo,
        ], ['Accept' => 'application/json'])->assertOk();

        $response->assertJsonPath('user.name', 'Nome Atualizado');
        $this->assertDatabaseHas('users', ['id' => $user->id, 'name' => 'Nome Atualizado']);
        $this->assertDatabaseHas('user_photos', ['user_id' => $user->id, 'mime_type' => 'image/jpeg']);

        $path = parse_url($response->json('user.photo_url'), PHP_URL_PATH);
        $this->get($path)
            ->assertOk()
            ->assertHeader('Content-Type', 'image/jpeg')
            ->assertContent($photo->getContent());
    }
}
