import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uri_move_app/core/api.dart';
import 'package:uri_move_app/models/models.dart';
import 'package:uri_move_app/services/api_repository.dart';

void main() {
  test('cancelRequest envia DELETE para a solicitação do passageiro', () async {
    late http.Request sent;
    final client = MockClient((request) async {
      sent = request;
      return http.Response('{"message":"Solicitação cancelada."}', 200);
    });
    final repository = ApiRepository(
      ApiClient(baseUrl: 'https://api.test/api/v1', client: client),
    );

    await repository.cancelRequest(7, 42);

    expect(sent.method, 'DELETE');
    expect(sent.url.path, '/api/v1/rides/7/requests/42');
  });

  test('Ride lê o id da solicitação do usuário', () {
    final ride = Ride.fromJson({
      'id': 7,
      'driver': {'id': 1, 'name': 'Ana'},
      'origin': 'Cerro Largo',
      'destination': 'Santo Ângelo',
      'total_seats': 3,
      'available_seats': 2,
      'my_request_status': 'accepted',
      'my_request_id': 42,
    });

    expect(ride.myRequestId, 42);
    expect(ride.myRequestStatus, 'accepted');
  });
}
