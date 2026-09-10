/// The four things about a Scan that can be changed between one Scan and the
/// next from a console, with no app update and no deploy: which model reads a
/// receipt, how hard it thinks first, how large an image it is given, and how
/// many Scans a day are paid for.
///
/// They are behaviour, not secrets. Whatever delivers them is readable by
/// anyone holding the app, which is fine for a model name and would be
/// disqualifying for a key — the key is a Worker secret and is never here.
library;

class Knobs {
  const Knobs({
    this.model = 'gpt-5-nano',
    this.effort = 'low',
    this.longEdge = 1024,
    this.dailyCap = 25,
  });

  /// Which model reads a receipt.
  final String model;

  /// How much reasoning to buy before the answer. `omit` leaves the setting
  /// out of the request entirely, for a tier that will not take one.
  ///
  /// This and [model] are deliberately unchecked at this end: the Worker holds
  /// both allowlists and falls back on anything it does not know, so a tier or
  /// an effort added there reaches phones without an app release — which is
  /// the whole point of a knob.
  final String effort;

  /// The long edge a receipt is stored and sent at. A portrait receipt
  /// saturates the model's patch budget at around 1440px, so anything larger
  /// bills identically while costing real upload bandwidth.
  final int longEdge;

  /// Scans a day, counted by the Worker. It lowers what the deployment allows
  /// and never raises it.
  final int dailyCap;

  /// A long edge outside this is a typo rather than a decision: below it the
  /// small print on a receipt is gone, and above it there is no camera on a
  /// phone that would fill it.
  static const smallestLongEdge = 256;
  static const largestLongEdge = 4096;

  static const modelKey = 'model';
  static const effortKey = 'reasoning_effort';
  static const longEdgeKey = 'image_long_edge';
  static const dailyCapKey = 'daily_cap';

  /// These values in the shape a console delivers them, which is what seeds
  /// one that has never been set up.
  Map<String, String> asDelivered() => {
    modelKey: model,
    effortKey: effort,
    longEdgeKey: '$longEdge',
    dailyCapKey: '$dailyCap',
  };

  @override
  bool operator ==(Object other) =>
      other is Knobs &&
      other.model == model &&
      other.effort == effort &&
      other.longEdge == longEdge &&
      other.dailyCap == dailyCap;

  @override
  int get hashCode => Object.hash(model, effort, longEdge, dailyCap);

  @override
  String toString() =>
      'Knobs(model: $model, effort: $effort, longEdge: $longEdge, '
      'dailyCap: $dailyCap)';
}

/// The knobs a console delivered, over the ones the app was compiled with.
/// Each is read on its own, so a console that sets one leaves the rest alone
/// and a value nobody could act on degrades to the compiled-in one rather than
/// taking scanning down.
Knobs knobsFrom(
  Map<String, String> delivered, {
  Knobs fallback = const Knobs(),
}) {
  final model = delivered[Knobs.modelKey];
  final effort = delivered[Knobs.effortKey];

  return Knobs(
    model: model == null || model.isEmpty ? fallback.model : model,
    effort: effort == null || effort.isEmpty ? fallback.effort : effort,
    longEdge:
        _wholeNumber(
          delivered[Knobs.longEdgeKey],
          atLeast: Knobs.smallestLongEdge,
          atMost: Knobs.largestLongEdge,
        ) ??
        fallback.longEdge,
    dailyCap: _wholeNumber(delivered[Knobs.dailyCapKey]) ?? fallback.dailyCap,
  );
}

int? _wholeNumber(String? text, {int atLeast = 0, int atMost = 1 << 30}) {
  final parsed = int.tryParse(text?.trim() ?? '');
  return parsed == null || parsed < atLeast || parsed > atMost ? null : parsed;
}
