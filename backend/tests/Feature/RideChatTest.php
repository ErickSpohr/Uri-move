<?php

namespace Tests\Feature;

use App\Models\Message;
use App\Models\Ride;
use App\Models\RideChatMessage;
use App\Models\RidePassenger;
use App\Models\RideRequest;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class RideChatTest extends TestCase
{
    use RefreshDatabase;

    public function test_pending_passenger_and_driver_can_chat_privately_before_acceptance(): void
    {
        $ride = Ride::factory()->create();
        $passenger = User::factory()->create();
        $stranger = User::factory()->create();
        RideRequest::create([
            'ride_id' => $ride->id,
            'passenger_id' => $passenger->id,
            'status' => RideRequest::STATUS_PENDING,
            'seats_requested' => 1,
        ]);

        Sanctum::actingAs($passenger);
        $this->postJson("/api/v1/rides/{$ride->id}/messages", ['body' => 'Posso levar uma mochila?'])
            ->assertCreated();

        Sanctum::actingAs($ride->driver);
        $this->getJson("/api/v1/rides/{$ride->id}/messages?user_id={$passenger->id}")
            ->assertOk()->assertJsonPath('data.0.body', 'Posso levar uma mochila?');
        $this->postJson("/api/v1/rides/{$ride->id}/messages", [
            'receiver_id' => $passenger->id,
            'body' => 'Sim, sem problema.',
        ])->assertCreated();
        $this->postJson("/api/v1/rides/{$ride->id}/messages", [
            'receiver_id' => $stranger->id,
            'body' => 'Olá',
        ])->assertForbidden();

        Sanctum::actingAs($stranger);
        $this->getJson("/api/v1/rides/{$ride->id}/messages")->assertForbidden();
    }

    public function test_private_chat_returns_latest_messages_after_fifty(): void
    {
        $ride = Ride::factory()->create();
        $passenger = User::factory()->create();
        RideRequest::create([
            'ride_id' => $ride->id,
            'passenger_id' => $passenger->id,
            'status' => RideRequest::STATUS_PENDING,
            'seats_requested' => 1,
        ]);

        for ($i = 1; $i <= 55; $i++) {
            Message::create([
                'ride_id' => $ride->id,
                'sender_id' => $passenger->id,
                'receiver_id' => $ride->driver_id,
                'body' => "Mensagem {$i}",
            ]);
        }

        Sanctum::actingAs($ride->driver);
        $response = $this->getJson("/api/v1/rides/{$ride->id}/messages?user_id={$passenger->id}")
            ->assertOk()
            ->assertJsonCount(50, 'data')
            ->assertJsonPath('data.49.body', 'Mensagem 55');

        $lastId = $response->json('data.49.id');
        $this->getJson("/api/v1/rides/{$ride->id}/messages?user_id={$passenger->id}&after_id=".($lastId - 2))
            ->assertOk()
            ->assertJsonCount(2, 'data');
    }

    public function test_driver_and_confirmed_passengers_share_messages(): void
    {
        $ride = Ride::factory()->create();
        $passenger = User::factory()->create();
        RidePassenger::create(['ride_id' => $ride->id, 'passenger_id' => $passenger->id, 'status' => 'confirmed']);
        Sanctum::actingAs($ride->driver);
        $this->postJson("/api/v1/rides/{$ride->id}/chat", ['body' => 'Estou na entrada.'])
            ->assertCreated()->assertJsonPath('data.sender.id', $ride->driver_id);
        Sanctum::actingAs($passenger);
        $this->getJson("/api/v1/rides/{$ride->id}/chat")
            ->assertOk()->assertJsonPath('data.0.body', 'Estou na entrada.');
        $this->postJson("/api/v1/rides/{$ride->id}/chat", ['body' => 'Já estou chegando.'])
            ->assertCreated()->assertJsonPath('data.sender.id', $passenger->id);
        $this->assertDatabaseCount('ride_chat_messages', 2);
    }

    public function test_strangers_and_cancelled_passengers_cannot_read_or_send(): void
    {
        $ride = Ride::factory()->create();
        $stranger = User::factory()->create();
        Sanctum::actingAs($stranger);
        $this->getJson("/api/v1/rides/{$ride->id}/chat")->assertForbidden();
        $this->postJson("/api/v1/rides/{$ride->id}/chat", ['body' => 'Oi'])->assertForbidden();
        RidePassenger::create(['ride_id' => $ride->id, 'passenger_id' => $stranger->id, 'status' => 'cancelled']);
        $this->getJson("/api/v1/rides/{$ride->id}/chat")->assertForbidden();
        $this->postJson("/api/v1/rides/{$ride->id}/chat", ['body' => 'Oi'])->assertForbidden();
        $this->assertDatabaseCount('ride_chat_messages', 0);
    }

    public function test_history_is_paginated_and_isolated_from_other_rides_and_private_messages(): void
    {
        $ride = Ride::factory()->create();
        $other = Ride::factory()->create();
        Sanctum::actingAs($ride->driver);
        Message::create(['ride_id' => $ride->id, 'sender_id' => $ride->driver_id, 'receiver_id' => $other->driver_id, 'body' => 'Privada']);
        RideChatMessage::create(['ride_id' => $other->id, 'sender_id' => $other->driver_id, 'body' => 'Outro grupo']);
        $ids = [];
        for ($i = 1; $i <= 55; $i++) {
            $ids[] = RideChatMessage::create(['ride_id' => $ride->id, 'sender_id' => $ride->driver_id, 'body' => "Mensagem {$i}"])->id;
        }
        $this->getJson("/api/v1/rides/{$ride->id}/chat")->assertOk()
            ->assertJsonCount(50, 'data')->assertJsonPath('data.0.body', 'Mensagem 6')
            ->assertJsonPath('data.49.body', 'Mensagem 55');
        $this->getJson("/api/v1/rides/{$ride->id}/chat?before_id={$ids[5]}")
            ->assertOk()->assertJsonCount(5, 'data')->assertJsonPath('data.0.body', 'Mensagem 1');
        $this->getJson("/api/v1/rides/{$ride->id}/chat?after_id={$ids[53]}")
            ->assertOk()->assertJsonCount(1, 'data')->assertJsonPath('data.0.body', 'Mensagem 55');
    }

    public function test_closed_rides_are_read_only_and_message_body_is_validated(): void
    {
        $ride = Ride::factory()->create();
        Sanctum::actingAs($ride->driver);
        $this->postJson("/api/v1/rides/{$ride->id}/chat", ['body' => '   '])->assertUnprocessable();
        $this->postJson("/api/v1/rides/{$ride->id}/chat", ['body' => str_repeat('a', 2001)])->assertUnprocessable();
        foreach (['completed', 'cancelled'] as $status) {
            $ride->update(['status' => $status]);
            $this->getJson("/api/v1/rides/{$ride->id}/chat")->assertOk();
            $this->postJson("/api/v1/rides/{$ride->id}/chat", ['body' => 'Oi'])->assertUnprocessable();
        }
        $this->assertDatabaseCount('ride_chat_messages', 0);
    }

    public function test_chat_requires_authentication(): void
    {
        $ride = Ride::factory()->create();
        $this->getJson("/api/v1/rides/{$ride->id}/chat")->assertUnauthorized();
        $this->postJson("/api/v1/rides/{$ride->id}/chat", ['body' => 'Oi'])->assertUnauthorized();
    }
}
