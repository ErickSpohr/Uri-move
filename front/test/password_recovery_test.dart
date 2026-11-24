import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:uri_move_app/core/api.dart';
import 'package:uri_move_app/screens/login_screen.dart';
import 'package:uri_move_app/screens/password_recovery_screen.dart';
import 'package:uri_move_app/state/auth_controller.dart';

void main() {
  testWidgets(
    'login recovery link requests a code and saves the new password',
    (tester) async {
      final requests = <http.Request>[];
      final auth = AuthController(
        client: ApiClient(
          client: MockClient((request) async {
            requests.add(request);
            return http.Response(jsonEncode({'message': 'OK'}), 200);
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
      final recoveryLink = find.text('Esqueci minha senha');
      await tester.ensureVisible(recoveryLink);
      await tester.tap(recoveryLink);
      await tester.pumpAndSettle();
      expect(find.byType(PasswordRecoveryScreen), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).last)
            .controller!
            .text,
        'student@uri.edu.br',
      );

      await tester.tap(find.text('Enviar código'));
      await tester.pumpAndSettle();
      expect(requests.single.url.path, '/api/v1/auth/forgot-password');
      expect(jsonDecode(requests.single.body)['email'], 'student@uri.edu.br');
      final fields = find.descendant(
        of: find.byType(PasswordRecoveryScreen),
        matching: find.byType(TextFormField),
      );
      final code = List.filled(64, 'a').join();
      await tester.enterText(fields.at(1), code);
      await tester.enterText(fields.at(2), 'new-password123');
      await tester.enterText(fields.at(3), 'new-password123');
      await tester.ensureVisible(find.text('Salvar nova senha'));
      await tester.tap(find.text('Salvar nova senha'));
      await tester.pumpAndSettle();

      expect(requests.last.url.path, '/api/v1/auth/reset-password');
      expect(jsonDecode(requests.last.body), {
        'email': 'student@uri.edu.br',
        'token': code,
        'password': 'new-password123',
        'password_confirmation': 'new-password123',
      });
      expect(find.byType(PasswordRecoveryScreen), findsNothing);
      expect(find.byType(LoginScreen), findsOneWidget);
    },
  );
}
