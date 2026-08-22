import 'package:coloro/app/coloro_app.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('main menu renders title and play CTA', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const ColoroApp());
    // Let the catalog/progress futures resolve with real async (the 300
    // level manifest + first preview take a moment). No pumpAndSettle:
    // the menu runs looping idle animations.
    await tester.runAsync(() => Future.delayed(const Duration(seconds: 2)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Title tiles spell COLORO.
    expect(find.text('C'), findsOneWidget);
    expect(find.text('R'), findsOneWidget);
    expect(find.text('PLAY'), findsOneWidget);
  });
}
