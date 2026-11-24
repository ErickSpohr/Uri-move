import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:uri_move_app/main.dart';

void main() {
  testWidgets('App bootstraps and shows splash', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const URIMoveApp());
    await tester.pump();

    expect(find.text('URI Move'), findsOneWidget);
  });
}