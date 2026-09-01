import 'package:test/test.dart';
import 'package:where_money_core/where_money_core.dart';

void main() {
  test('the fixtures only ever use Categories the taxonomy knows', () {
    for (final extraction in [cleanExtraction, flawedExtraction]) {
      expect(categories, contains(extraction.category));
      expect(paymentMethods, contains(extraction.paymentMethod));
      for (final item in extraction.lineItems) {
        expect(categories, contains(item.category));
      }
    }
  });
}
