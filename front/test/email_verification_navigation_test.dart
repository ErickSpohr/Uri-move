import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:uri_move_app/core/api.dart';
import 'package:uri_move_app/screens/login_screen.dart';
import 'package:uri_move_app/screens/verify_screen.dart';
import 'package:uri_move_app/state/auth_controller.dart';

void main() {
  testWidgets('unverified login opens the email verification screen', (
    tester,
  ) async {
    final requests = <http.Request>[];
    final auth = AuthController(
      client: ApiClient(
        client: MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode({
              'message':
                  'E-mail ainda não verificado. Um novo código foi enviado.',
              'requires_email_verification': true,
              'user': {
                'id': 1,
                'name': 'Aluno Teste',
                'email': 'student@uri.edu.br',
              },
            }),
            403,
            headers: {'content-type': 'application/json'},
          );
        }),
      ),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: auth,
        child: const MaterialApp(home: LoginScreen()),
      ),
    );

    await tester.enterText(
      find.byType(TextFormField).first,
      'student@uri.edu.br',
    );
    await tester.enterText(find.byType(TextFormField).last, 'password123');
    await tester.tap(find.text('Entrar').last);
    await tester.pumpAndSettle();

    expect(requests.single.url.path, '/api/v1/auth/login');
    expect(find.byType(VerifyScreen), findsOneWidget);
    expect(find.textContaining('student@uri.edu.br'), findsOneWidget);
    expect(find.text('Verificar e continuar'), findsOneWidget);
  });
}
