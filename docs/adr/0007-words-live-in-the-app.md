---
status: accepted
---

# Words live in the app; the domain holds kinds

`packages/core` carries no human-readable text. A Category is the slug
`personal_care`, a payment method is `bank_transfer`, a month is a year and a
number, and a Finding is one of seventeen kinds carrying the values its
sentence interpolates. Everything a user reads is assembled in `lib/`, where
the app can localize it.

The alternative was real: core takes an internationalisation dependency and
localizes itself. It was rejected to keep the package pure Dart and
dependency-free, which is what lets the Check, the Rollup and the prompt be
tested with `dart test` and reasoned about without a Flutter toolchain. The
mismatch is not only technical — nine of the Findings interpolate a value
mid-sentence, and a language that places numbers differently needs the value
and the sentence to arrive separately anyway.

This has consequences a future reader will trip over, so they are worth naming.
A `Finding` cannot describe itself; `lib/review/finding_copy.dart` is the one
exhaustive switch that turns a kind into words, and adding a kind without copy
is a compile error. A `Rollup` cannot name its own month; the screen formats one
from the year and month it exposes. And the Recap prompt sends the year and the
month as numbers and Categories as slugs, so the Model — which is the thing
writing in the user's language — names them itself.

Two tests keep this from being a one-time tidy: `flutter_free_test.dart` asserts
core declares no Flutter dependency, and `no_words_in_the_domain_test.dart`
reads core's source and fails on any string literal that is not a slug, a wire
key or a number. The second one carries a short allowlist, each entry with its
reason.
