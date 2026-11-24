import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uri_move_app/core/api.dart';
import 'package:uri_move_app/models/models.dart';
import 'package:uri_move_app/screens/ride_chat_screen.dart';
import 'package:uri_move_app/state/auth_controller.dart';

void main() {
  testWidgets('chat sends and receives messages without refreshing the page', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final messages = <Map<String, dynamic>>[];
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/auth/login')) {
        return http.Response(
          jsonEncode({
            'token': 'test-token',
            'user': {
              'id': 1,
              'name': 'Motorista',
              'email': 'driver@example.test',
            },
          }),
          200,
        );
      }
      if (request.method == 'POST') {
        messages.add({
          'id': messages.length + 1,
          'sender': {'id': 1, 'name': 'Motorista'},
          'body': jsonDecode(request.body)['body'],
        });
        return http.Response(jsonEncode({'data': messages.last}), 201);
      }
      final after =
          int.tryParse(request.url.queryParameters['after_id'] ?? '') ?? 0;
      return http.Response(
        jsonEncode({
          'data': messages.where((m) => (m['id'] as int) > after).toList(),
        }),
        200,
      );
    });
    final auth = AuthController(client: ApiClient(client: client));
    await auth.login('driver@example.test', 'password');
    final ride = Ride(
      id: 1,
      driver: User(id: 1, name: 'Motorista', email: ''),
      origin: 'Centro',
      destination: 'URI',
      canChat: true,
    );
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: auth,
        child: MaterialApp(home: RideChatScreen(ride: ride)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Estou na entrada');
    await tester.tap(find.byTooltip('Enviar mensagem'));
    await tester.pumpAndSettle();
    expect(find.text('Estou na entrada'), findsOneWidget);

    messages.add({
      'id': 2,
      'sender': {'id': 2, 'name': 'Passageiro'},
      'body': 'Estou chegando',
    });
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Estou chegando'), findsOneWidget);
    expect(find.text('Passageiro'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    auth.dispose();
  });
}
