import 'package:flutter_test/flutter_test.dart';
import 'package:where_money/main.dart';

void main() {
  testWidgets('the app opens on a placeholder screen', (tester) async {
    await tester.pumpWidget(const WhereMoneyApp());

    expect(find.text('where_money'), findsOneWidget);
    expect(find.text('Nothing here yet.'), findsOneWidget);
  });
}
