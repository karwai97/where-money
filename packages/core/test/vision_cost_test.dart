import 'package:test/test.dart';
import 'package:where_money_core/where_money_core.dart';

void main() {
  test('patches are counted in whole 32-pixel blocks', () {
    expect(patchCount(64, 64), 4);
    expect(patchCount(65, 64), 6);
  });

  test('a portrait receipt saturates the patch budget at 1440px', () {
    expect(budgetCeilingLongEdge(ModelTier.nano5), 1440);
    expect(patchCount(1080, 1440), 1530);
    expect(patchCount(1092, 1456), greaterThan(ModelTier.nano5.patchBudget));
  });

  test('asking for more than the ceiling bills exactly the same', () {
    final atCeiling = planImage(
      width: 1536,
      height: 2048,
      clientMaxLongEdge: 1440,
    );
    final wayOver = planImage(
      width: 1536,
      height: 2048,
      clientMaxLongEdge: 2576,
    );

    expect(wayOver.imageTokens, atCeiling.imageTokens);
    expect(wayOver.overBudget, isTrue);
    expect(atCeiling.overBudget, isFalse);
  });

  test('a 1440px receipt costs the nano tier a known number of tokens', () {
    final plan = planImage(width: 1536, height: 2048, clientMaxLongEdge: 1440);

    expect(plan.sentWidth, 1080);
    expect(plan.sentHeight, 1440);
    expect(plan.patches, 1530);
    expect(plan.imageTokens, 3764);
    expect(plan.imageCostUsd, closeTo(0.0001882, 1e-9));
    expect(plan.downscaledByUs, isTrue);
  });

  test('a small photo is sent as it is', () {
    final plan = planImage(width: 640, height: 480, clientMaxLongEdge: 1024);

    expect(plan.sentWidth, 640);
    expect(plan.sentHeight, 480);
    expect(plan.downscaledByUs, isFalse);
    expect(plan.overBudget, isFalse);
  });

  test('the service downscales anything we send over the budget', () {
    final plan = planImage(
      width: 3024,
      height: 4032,
      clientMaxLongEdge: 4032,
      model: ModelTier.nano5,
    );

    expect(plan.overBudget, isTrue);
    expect(plan.patches, lessThanOrEqualTo(ModelTier.nano5.patchBudget));
    expect(plan.sentHeight, lessThan(4032));
  });

  test('the cheaper tier per token is only 3.3x cheaper per image', () {
    final nano = planImage(width: 1080, height: 1440, clientMaxLongEdge: 1440);
    final mini = planImage(
      width: 1080,
      height: 1440,
      clientMaxLongEdge: 1440,
      model: ModelTier.mini5,
    );

    expect(
      ModelTier.mini5.inputPerMTok / ModelTier.nano5.inputPerMTok,
      closeTo(5.0, 0.001),
    );
    expect(mini.imageCostUsd / nano.imageCostUsd, closeTo(3.29, 0.01));
  });

  test('a scan is priced from both halves of the call', () {
    expect(
      ModelTier.nano5.cost(inputTokens: 4000, outputTokens: 1200),
      closeTo(0.0002 + 0.00048, 1e-9),
    );
  });

  group('fitting a photograph to a long edge', () {
    test('a phone-resolution portrait receipt comes down to the long edge', () {
      final fitted = fitToLongEdge(3024, 4032, 1024);

      expect(fitted.height, 1024);
      expect(fitted.width, 768);
    });

    test('a landscape photograph is measured on its width', () {
      final fitted = fitToLongEdge(4032, 3024, 1024);

      expect(fitted.width, 1024);
      expect(fitted.height, 768);
    });

    test('an image already inside the long edge is left exactly alone', () {
      final fitted = fitToLongEdge(800, 600, 1024);

      expect(fitted.width, 800);
      expect(fitted.height, 600);
    });

    test('1024 on the long edge stays under the patch budget, which is the '
        'whole reason for the number', () {
      final fitted = fitToLongEdge(3024, 4032, 1024);

      expect(
        patchCount(fitted.width, fitted.height),
        lessThanOrEqualTo(ModelTier.nano5.patchBudget),
      );
    });
  });
}
