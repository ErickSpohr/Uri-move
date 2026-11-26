import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uri_move_app/core/api.dart';
import 'package:uri_move_app/core/push_notifications.dart';
import 'package:latlong2/latlong.dart';
import 'package:uri_move_app/models/models.dart';
import 'package:uri_move_app/screens/ride_tracking_screen.dart';
import 'package:uri_move_app/services/api_repository.dart';
import 'package:uri_move_app/services/route_service.dart';

const _rideJson = {
  'id': 7,
  'driver': {'id': 1, 'name': 'Ana'},
  'origin': 'Cerro Largo',
  'destination': 'Santo Ângelo',
};

ApiRepository _repository(List<http.Request> sent, Map<String, dynamic> body) {
  final client = MockClient((request) async {
    sent.add(request);
    return http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });
  return ApiRepository(
    ApiClient(baseUrl: 'https://api.test/api/v1', client: client),
  );
}

void main() {
  test('createRide envia repetição semanal e lê o total criado', () async {
    final sent = <http.Request>[];
    final repository = _repository(sent, {
      'ride': _rideJson,
      'rides_created': 6,
    });

    final result = await repository.createRide(
      origin: 'Cerro Largo',
      destination: 'URI',
      departureDate: '2026-12-07',
      departureTime: '07:30',
      totalSeats: 3,
      womenOnly: true,
      repeatDays: const [1, 3, 5],
      repeatUntil: '2026-12-18',
    );

    final body = jsonDecode(sent.single.body) as Map<String, dynamic>;
    expect(body['repeat_days'], [1, 3, 5]);
    expect(body['repeat_until'], '2026-12-18');
    expect(body['women_only'], true);
    expect(result.created, 6);
    expect(result.ride.id, 7);
  });

  test('cancelRide com série envia scope=series', () async {
    final sent = <http.Request>[];
    final repository = _repository(sent, {
      'ride': _rideJson,
      'cancelled_count': 3,
    });

    final result = await repository.cancelRide(7, wholeSeries: true);

    expect(jsonDecode(sent.single.body), {'scope': 'series'});
    expect(result.cancelled, 3);
  });

  test('rides envia filtros de horário, preço e só mulheres', () async {
    final sent = <http.Request>[];
    final repository = _repository(sent, {'data': <dynamic>[]});

    await repository.rides(
      fromTime: '05:00',
      toTime: '11:59',
      priceMax: 0,
      womenOnly: true,
    );

    expect(sent.single.url.queryParameters, {
      'from_time': '05:00',
      'to_time': '11:59',
      'price_max': '0.00',
      'women_only': '1',
    });
  });

  test('modelos leem Pix, série e exclusividade feminina', () {
    final ride = Ride.fromJson({
      ..._rideJson,
      'series_id': 'abc',
      'women_only': true,
      'driver_pix_key': 'ana@uri.edu.br',
    });
    final user = User.fromJson({
      'id': 1,
      'name': 'Ana',
      'gender': 'woman',
      'pix_key': '123',
    });

    expect(ride.seriesId, 'abc');
    expect(ride.womenOnly, isTrue);
    expect(ride.driverPixKey, 'ana@uri.edu.br');
    expect(user.isWoman, isTrue);
    expect(user.pixKey, '123');
  });

  test('push fica desativado fora do navegador', () async {
    expect(pushSupported(), isFalse);
    expect(await pushCurrentSubscription(), isNull);
    expect(await pushUnsubscribe(), isNull);
  });

  test('requestRide envia o ponto de encontro', () async {
    final sent = <http.Request>[];
    final repository = _repository(sent, {
      'request': {
        'id': 3,
        'ride_id': 7,
        'status': 'pending',
        'pickup_lat': -28.1,
        'pickup_lng': -54.7,
        'pickup_label': 'Praça',
      },
    });

    final request = await repository.requestRide(
      7,
      pickupLat: -28.1,
      pickupLng: -54.7,
      pickupLabel: 'Praça',
    );

    final body = jsonDecode(sent.single.body) as Map<String, dynamic>;
    expect(body['pickup_lat'], -28.1);
    expect(body['pickup_label'], 'Praça');
    expect(request.hasPickup, isTrue);
  });

  test('RouteService lê geometria GeoJSON (lng, lat) do OSRM', () {
    final route = RouteService.parse({
      'code': 'Ok',
      'routes': [
        {
          'distance': 3200.5,
          'duration': 400.0,
          'geometry': {
            'coordinates': [
              [-54.74, -28.15],
              [-54.26, -28.30],
            ],
          },
        },
      ],
    })!;

    expect(route.points.first, const LatLng(-28.15, -54.74));
    expect(route.durationSeconds, 400);
    expect(RouteService.parse({'code': 'NoRoute', 'routes': []}), isNull);
  });

  test('TrackingStop lê a parada do passageiro', () {
    final stop = TrackingStop.fromJson({
      'passenger_id': 5,
      'passenger_name': 'Ana Souza',
      'latitude': -28.1,
      'longitude': -54.7,
      'picked_up': true,
    });

    expect(stop.position, const LatLng(-28.1, -54.7));
    expect(stop.pickedUp, isTrue);
  });
}
