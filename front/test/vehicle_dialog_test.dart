import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:uri_move_app/core/api.dart';
import 'package:uri_move_app/models/models.dart';
import 'package:uri_move_app/state/auth_controller.dart';
import 'package:uri_move_app/widgets/vehicle_dialog.dart';

void main() {
  testWidgets('edits an existing vehicle with a PUT request', (tester) async {
    late http.Request request;
    final auth = AuthController(
      client: ApiClient(
        client: MockClient((incoming) async {
          request = incoming;
          return http.Response(
            jsonEncode({
              'vehicle': {
                'id': 7,
                'brand': 'Volkswagen',
                'model': 'Gol Special',
                'color': 'Prata',
                'plate': 'ABC1D23',
                'year': 2015,
                'seats': 5,
                'is_active': true,
              },
            }),
            200,
          );
        }),
      ),
    );
    final vehicle = Vehicle(
      id: 7,
      brand: 'Volkswagen',
      model: 'Gol',
      color: 'Prata',
      plate: 'ABC1D23',
      year: 2015,
      seats: 4,
    );

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: auth,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<Vehicle>(
                  context: context,
                  builder: (_) => VehicleDialog(vehicle: vehicle),
                ),
                child: const Text('Editar'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    expect(find.text('Editar veículo'), findsOneWidget);
    expect(find.text('Volkswagen'), findsOneWidget);
    expect(find.text('Gol'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Modelo (ex.: Argo)'),
      'Gol Special',
    );
    await tester.tap(find.byIcon(Icons.add));
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(request.method, 'PUT');
    expect(request.url.path, '/api/v1/vehicles/7');
    expect(jsonDecode(request.body), {
      'brand': 'Volkswagen',
      'model': 'Gol Special',
      'color': 'Prata',
      'plate': 'ABC1D23',
      'year': 2015,
      'seats': 5,
      'fuel_consumption': null,
    });
    expect(find.text('Editar veículo'), findsNothing);
  });
}
