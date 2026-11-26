import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:uri_move_app/main.dart';
import 'package:uri_move_app/widgets/common.dart';

void main() {
  testWidgets('App bootstraps and shows splash', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const URIMoveApp());
    await tester.pump();

    expect(find.byType(AppLogo), findsOneWidget);
    expect(find.text('Caronas entre universitários da URI'), findsOneWidget);
  });
}