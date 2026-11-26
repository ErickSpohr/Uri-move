<?php

namespace Tests\Feature;

use App\Models\Message;
use App\Models\Rating;
use App\Models\Ride;
use App\Models\RideChatMessage;
use App\Models\RidePassenger;
use App\Models\RideRequest;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ChatUnreadAndParticipantsTest extends TestCase
{
    use RefreshDatabase;

    public function test_group_chat_unread_count_resets_after_opening_chat(): void
    {
        $ride = Ride::factory()->create();
        $passenger = User::factory()->create();
        RidePassenger::create(['ride_id' => $ride->id, 'passenger_id' => $passenger->id, 'status' => 'confirmed']);
        RideChatMessage::create(['ride_id' => $ride->id, 'sender_id' => $ride->driver_id, 'body' => 'Saindo às 7h.']);
        RideChatMessage::create(['ride_id' => $ride->id, 'sender_id' => $ride->driver_id, 'body' => 'Em frente ao bloco A.']);

        Sanctum::actingAs($passenger);
        $this->getJson('/api/v1/chats/unread')
            ->assertOk()
            ->assertJsonPath('total', 2)
            ->assertJsonPath('rides.0.ride_id', $ride->id)
            ->assertJsonPath('rides.0.count', 2);

        $this->getJson("/api/v1/rides/{$ride->id}/chat")->assertOk();

        $this->getJson('/api/v1/chats/unread')->assertOk()->assertJsonPath('total', 0);
    }

    public function test_own_group_messages_are_not_counted_as_unread(): void
    {
        $ride = Ride::factory()->create();
        RideChatMessage::create(['ride_id' => $ride->id, 'sender_id' => $ride->driver_id, 'body' => 'Mensagem minha.']);

        Sanctum::actingAs($ride->driver);
        $this->getJson('/api/v1/chats/unread')->assertOk()->assertJsonPath('total', 0);
    }

    public function test_private_unread_count_resets_after_opening_conversation(): void
    {
        $ride = Ride::factory()->create();
        $passenger = User::factory()->create();
        RideRequest::create([
            'ride_id' => $ride->id,
            'passenger_id' => $passenger->id,
            'status' => RideRequest::STATUS_PENDING,
            'seats_requested' => 1,
        ]);
        Message::create([
            'ride_id' => $ride->id,
            'sender_id' => $passenger->id,
            'receiver_id' => $ride->driver_id,
            'body' => 'Tem lugar para mochila?',
        ]);

        Sanctum::actingAs($ride->driver);
        $this->getJson('/api/v1/chats/unread')
            ->assertOk()
            ->assertJsonPath('total', 1)
            ->assertJsonPath('private.0.user_id', $passenger->id);

        $this->getJson("/api/v1/rides/{$ride->id}/messages?user_id={$passenger->id}")->assertOk();

        $this->getJson('/api/v1/chats/unread')->assertOk()->assertJsonPath('total', 0);
    }

    public function test_participants_list_excludes_self_and_flags_rated_users(): void
    {
        $ride = Ride::factory()->create(['status' => Ride::STATUS_COMPLETED]);
        $passenger = User::factory()->create();
        $otherPassenger = User::factory()->create();
        RidePassenger::create(['ride_id' => $ride->id, 'passenger_id' => $passenger->id, 'status' => 'completed']);
        RidePassenger::create(['ride_id' => $ride->id, 'passenger_id' => $otherPassenger->id, 'status' => 'completed']);
        Rating::create(['ride_id' => $ride->id, 'rater_id' => $passenger->id, 'rated_id' => $ride->driver_id, 'score' => 5]);

        Sanctum::actingAs($passenger);
        $response = $this->getJson("/api/v1/rides/{$ride->id}/participants")
            ->assertOk()
            ->assertJsonPath('can_rate', true)
            ->assertJsonCount(2, 'data');

        $byId = collect($response->json('data'))->keyBy('user.id');
        $this->assertSame('driver', $byId[$ride->driver_id]['role']);
        $this->assertTrue($byId[$ride->driver_id]['already_rated']);
        $this->assertFalse($byId[$otherPassenger->id]['already_rated']);
        $this->assertArrayNotHasKey($passenger->id, $byId->all());
    }

    public function test_non_participant_cannot_list_participants(): void
    {
        $ride = Ride::factory()->create(['status' => Ride::STATUS_COMPLETED]);

        Sanctum::actingAs(User::factory()->create());
        $this->getJson("/api/v1/rides/{$ride->id}/participants")->assertForbidden();
    }
}
