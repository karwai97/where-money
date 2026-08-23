/// What a photographed receipt costs to read, and how small it can be sent
/// before the small print stops being readable. Entirely offline, so unit
/// economics can be reasoned about without spending anything.
///
/// The gpt-5 family bills images by 32x32 *patches*, not by fixed tiles:
///   patches      = ceil(w / 32) * ceil(h / 32)
///   over budget  -> the service scales the image down until it fits
///   image tokens = final patch count * a per-model multiplier
///
/// The multiplier is the trap. The nano tier is five times cheaper per token
/// than mini but charges 2.46 tokens per patch against mini's 1.62, so the real
/// gap is ~3.3x, not 5x. Cheapest-per-token is not cheapest-per-receipt.
///
/// This prices the *input* side only. Output tokens cost 8x input on the nano
/// tier, so they are the larger half of a scan's bill even though the image is
/// far more numerous: shrinking the image is the weaker lever, keeping output
/// tight is the stronger one.
/// Reference: developers.openai.com/api/docs/guides/images-vision
library;

import 'dart:math' as math;

class ModelTier {
  final String id;
  final String label;

  /// USD per million tokens.
  final double inputPerMTok;
  final double outputPerMTok;

  /// Tokens charged per 32x32 image patch.
  final double imageMultiplier;

  /// Patch ceiling before the service downscales the image.
  final int patchBudget;

  const ModelTier({
    required this.id,
    required this.label,
    required this.inputPerMTok,
    required this.outputPerMTok,
    required this.imageMultiplier,
    required this.patchBudget,
  });

  /// The cheapest vision-capable tier, and the default. Whether it reads dense
  /// receipt print accurately is the question the Corrected Fields tally
  /// exists to answer.
  static const nano5 = ModelTier(
    id: 'gpt-5-nano',
    label: 'gpt-5-nano · cheapest',
    inputPerMTok: 0.05,
    outputPerMTok: 0.40,
    imageMultiplier: 2.46,
    patchBudget: 1536,
  );

  /// The fallback if nano starts misreading totals. ~3.3x the image cost.
  static const mini5 = ModelTier(
    id: 'gpt-5-mini',
    label: 'gpt-5-mini · safer',
    inputPerMTok: 0.25,
    outputPerMTok: 2.00,
    imageMultiplier: 1.62,
    patchBudget: 1536,
  );

  double cost({required int inputTokens, required int outputTokens}) =>
      inputTokens / 1e6 * inputPerMTok + outputTokens / 1e6 * outputPerMTok;

  int imageTokens(int patches) => (patches * imageMultiplier).round();
}

class ImagePlan {
  final int sentWidth;
  final int sentHeight;
  final int patches;
  final int imageTokens;
  final bool downscaledByUs;
  final bool overBudget;
  final ModelTier model;

  const ImagePlan({
    required this.sentWidth,
    required this.sentHeight,
    required this.patches,
    required this.imageTokens,
    required this.downscaledByUs,
    required this.overBudget,
    required this.model,
  });

  double get imageCostUsd => imageTokens / 1e6 * model.inputPerMTok;
}

int patchCount(int width, int height) =>
    (width / 32).ceil() * (height / 32).ceil();

/// Shrinks (w, h) until it fits the patch budget, preserving aspect ratio —
/// mirroring what the service does server-side to anything larger.
({int width, int height}) fitToBudget(int width, int height, int budget) {
  if (patchCount(width, height) <= budget) {
    return (width: width, height: height);
  }

  // Start from the area-based estimate, then walk down: patch counts are
  // ceilings, so the closed-form answer can still land a patch or two over.
  var scale = math.sqrt(budget * 1024 / (width * height));
  var fittedWidth = math.max(32, (width * scale).floor());
  var fittedHeight = math.max(32, (height * scale).floor());

  while (patchCount(fittedWidth, fittedHeight) > budget &&
      fittedWidth > 32 &&
      fittedHeight > 32) {
    scale *= 0.98;
    fittedWidth = math.max(32, (width * scale).floor());
    fittedHeight = math.max(32, (height * scale).floor());
  }
  return (width: fittedWidth, height: fittedHeight);
}

/// [clientMaxLongEdge] is the size the phone resizes to before uploading — the
/// main cost lever the app controls, and the main accuracy risk on faint
/// thermal print.
ImagePlan planImage({
  required int width,
  required int height,
  required int clientMaxLongEdge,
  ModelTier model = ModelTier.nano5,
}) {
  final longEdge = math.max(width, height);
  final ourScale = longEdge > clientMaxLongEdge
      ? clientMaxLongEdge / longEdge
      : 1.0;
  final ourWidth = math.max(32, (width * ourScale).floor());
  final ourHeight = math.max(32, (height * ourScale).floor());

  final overBudget = patchCount(ourWidth, ourHeight) > model.patchBudget;
  final fitted = fitToBudget(ourWidth, ourHeight, model.patchBudget);
  final patches = patchCount(fitted.width, fitted.height);

  return ImagePlan(
    sentWidth: fitted.width,
    sentHeight: fitted.height,
    patches: patches,
    imageTokens: model.imageTokens(patches),
    downscaledByUs: ourScale < 1.0,
    overBudget: overBudget,
    model: model,
  );
}

/// Above this long edge a 3:4 portrait receipt already exceeds the patch
/// budget, so uploading anything larger costs bandwidth and buys nothing.
int budgetCeilingLongEdge(ModelTier model, {double aspect = 0.75}) {
  var edge = 320;
  while (edge < 4096) {
    final next = edge + 16;
    if (patchCount((next * aspect).round(), next) > model.patchBudget) {
      return edge;
    }
    edge = next;
  }
  return edge;
}
