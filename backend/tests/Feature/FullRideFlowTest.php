<?php

namespace Tests\Feature;

use App\Models\EmailVerification;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Auth;
use Tests\TestCase;

/**
 * Jornada completa pela API, como o app faz: cadastro e verificação de dois usuários,
 * publicação, busca, solicitação, conversa, aceite, chat em grupo, rastreamento,
 * conclusão, avaliação mútua e notificações.
 */
class FullRideFlowTest extends TestCase
{
    use RefreshDatabase;

    /**
     * Cadastra e verifica um usuário; devolve o token emitido na verificação.
     */
    private function registerAndVerify(string $name, string $email): string
    {
        $this->postJson('/api/v1/auth/register', [
            'name' => $name,
            'email' => $email,
            'password' => 'senha-segura-1',
            'password_confirmation' => 'senha-segura-1',
        ])->assertCreated();

        $user = User::where('email', $email)->firstOrFail();
        $code = EmailVerification::where('user_id', $user->id)->latest('id')->value('code');

        return $this->postJson('/api/v1/auth/verify-email', ['email' => $email, 'code' => $code])
            ->assertOk()
            ->assertJsonPath('user.email', $email)
            ->json('token');
    }

    /**
     * Requisição autenticada com o token informado (como o app envia).
     */
    private function as(string $token): static
    {
        Auth::forgetGuards();

        return $this->withToken($token);
    }

    public function test_complete_ride_journey_between_driver_and_passenger(): void
    {
        $driverToken = $this->registerAndVerify('Motorista Teste', 'motorista.fluxo@uri.edu.br');
        $passengerToken = $this->registerAndVerify('Passageira Teste', 'passageira.fluxo@uri.edu.br');
        $driverId = User::where('email', 'motorista.fluxo@uri.edu.br')->value('id');
        $passengerId = User::where('email', 'passageira.fluxo@uri.edu.br')->value('id');

        // Motorista cadastra veículo e publica a carona.
        $vehicleId = $this->as($driverToken)->postJson('/api/v1/vehicles', [
            'brand' => 'Fiat', 'model' => 'Argo', 'plate' => 'IXY1A23', 'seats' => 4,
        ])->assertCreated()->json('vehicle.id');

        $rideId = $this->as($driverToken)->postJson('/api/v1/rides', [
            'vehicle_id' => $vehicleId,
            'origin' => 'Cerro Largo',
            'destination' => 'URI Santo Ângelo',
            'departure_date' => now()->addDay()->toDateString(),
            'departure_time' => '07:30',
            'total_seats' => 3,
            'price' => 12.5,
        ])->assertCreated()->json('ride.id');

        // Passageira encontra a carona na busca, sem ver o contato do motorista.
        $found = $this->as($passengerToken)->getJson('/api/v1/rides?destination=santo')
            ->assertOk()
            ->assertJsonPath('data.0.id', $rideId)
            ->assertJsonPath('data.0.my_request_status', null)
            ->json('data.0');
        $this->assertArrayNotHasKey('email', $found['driver']);

        // Solicita vaga e conversa em privado antes do aceite.
        $requestId = $this->as($passengerToken)->postJson("/api/v1/rides/{$rideId}/requests", ['seats_requested' => 1])
            ->assertCreated()->json('request.id');
        $this->as($passengerToken)->postJson("/api/v1/rides/{$rideId}/messages", ['body' => 'Posso levar mochila?'])
            ->assertCreated();

        // Motorista vê a mensagem como não lida, abre a conversa e aceita.
        $this->as($driverToken)->getJson('/api/v1/chats/unread')
            ->assertOk()->assertJsonPath('total', 1)->assertJsonPath('private.0.user_id', $passengerId);
        $this->as($driverToken)->getJson("/api/v1/rides/{$rideId}/messages?user_id={$passengerId}")
            ->assertOk()->assertJsonPath('data.0.body', 'Posso levar mochila?');
        $this->as($driverToken)->getJson('/api/v1/chats/unread')->assertOk()->assertJsonPath('total', 0);
        $this->as($driverToken)->patchJson("/api/v1/rides/{$rideId}/requests/{$requestId}", ['action' => 'accepted'])
            ->assertOk();

        $this->as($passengerToken)->getJson("/api/v1/rides/{$rideId}")
            ->assertOk()
            ->assertJsonPath('data.my_request_status', 'accepted')
            ->assertJsonPath('data.can_chat', true)
            ->assertJsonPath('data.available_seats', 2);

        // Chat em grupo com contador de não lidas.
        $this->as($driverToken)->postJson("/api/v1/rides/{$rideId}/chat", ['body' => 'Saio às 7h30 da praça.'])
            ->assertCreated();
        $this->as($passengerToken)->getJson('/api/v1/chats/unread')
            ->assertOk()->assertJsonPath('rides.0.ride_id', $rideId)->assertJsonPath('rides.0.count', 1);
        $this->as($passengerToken)->getJson("/api/v1/rides/{$rideId}/chat")->assertOk();
        $this->as($passengerToken)->getJson('/api/v1/chats/unread')->assertOk()->assertJsonPath('total', 0);

        // Início, rastreamento e conclusão.
        $this->as($driverToken)->postJson("/api/v1/rides/{$rideId}/start")->assertOk();
        $this->as($driverToken)->putJson("/api/v1/rides/{$rideId}/location", ['latitude' => -28.1, 'longitude' => -54.7])
            ->assertOk();
        $this->as($passengerToken)->getJson("/api/v1/rides/{$rideId}/location")->assertOk();
        $this->as($passengerToken)->deleteJson("/api/v1/rides/{$rideId}/requests/{$requestId}")->assertUnprocessable();
        $this->as($driverToken)->postJson("/api/v1/rides/{$rideId}/complete")->assertOk();

        // Avaliação mútua.
        $this->as($passengerToken)->getJson("/api/v1/rides/{$rideId}/participants")
            ->assertOk()->assertJsonPath('can_rate', true)->assertJsonPath('data.0.already_rated', false);
        $this->as($passengerToken)->postJson('/api/v1/ratings', ['ride_id' => $rideId, 'rated_id' => $driverId, 'score' => 5])
            ->assertCreated();
        $this->as($driverToken)->postJson('/api/v1/ratings', ['ride_id' => $rideId, 'rated_id' => $passengerId, 'score' => 4])
            ->assertCreated();
        $this->as($passengerToken)->getJson("/api/v1/rides/{$rideId}/participants")
            ->assertOk()->assertJsonPath('data.0.already_rated', true);

        $this->assertSame(5.0, (float) User::find($driverId)->rating_avg);
        $this->assertSame(1, User::find($driverId)->ride_count);

        // Notificações geradas ao longo do fluxo.
        $this->as($passengerToken)->getJson('/api/v1/notifications')->assertOk()->assertJsonFragment(['type' => 'ride_request_accepted']);
        $this->as($driverToken)->getJson('/api/v1/notifications')->assertOk()->assertJsonFragment(['type' => 'rating_received']);
    }
}
