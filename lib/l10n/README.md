# The app's words

One ARB file per language, and `AppLocalizations` generated from them by
`flutter pub get` and by every build. `l10n.yaml` is the configuration; the
generated Dart is build output and is gitignored.

The domain package holds no words at all — a Category, a payment method and a
month are slugs there and labels here (ADR-0007). This directory is the other
end of that rule.

## Keys

**camelCase, prefixed by the screen the words appear on.** `settingsTitle`,
`settingsLockBiometrics`, `ledgerEmpty`. Roughly three hundred keys end up in
one flat namespace, and the prefix is what keeps "did I miss one on this
screen" answerable by reading down the file.

The prefix is the screen, not the widget: a string that moves between two
widgets on the same screen should not have to be renamed to stay honest.

**A closed set the domain owns is prefixed by the set instead** — `category*`,
`paymentMethod*`, `field*`, `expenseSource*`. Those are read on more than one
screen, so a screen prefix would be a lie about where they appear, and the
honest alternative is one copy per screen, which is the drift the single
definition exists to prevent. Nothing else earns the exception: a set here
means a slug in `packages/core` and a coverage test naming every member.

`merchantUnknown` is the same argument about a field rather than a set. A
merchant's name is transcribed and never translated; *not having one* is a word
this app chooses, and it is read on three screens. One key, prefixed by the
thing it names.

Every one of these is reached through a function in `on_screen.dart` rather
than by a screen calling `words.` directly, which is what makes "one
definition" true rather than intended.

## Messages, not fragments

A sentence is one key, placeholders included. Concatenating a translated
fragment onto a number does not survive a second language — the number goes
somewhere else in the sentence, and the plural rule is not English's.

```
"settingsScansDailyCap": "{count, plural, =1{Daily cap: 1 Scan} other{Daily cap: {count} Scans}}"
```

Each language carries its own CLDR plural categories, not English's. Chinese,
Japanese, Korean and Indonesian have one form, so their version of a plural
message carries `other` alone; Russian carries `one`, `few`, `many` and
`other`; Arabic carries all six. That is correct, not a missing translation.

## Every file is hand-written

One ARB file per code in `languages` (`packages/core/lib/src/language.dart`),
and every key exists in every one of them, in real prose. `l10n.yaml` writes
anything missing to `l10n-untranslated.json`, and that file should stay empty
— a key that silently falls back to English is a screen that is half migrated
and looks finished.

`test/l10n/every_language_says_everything_test.dart` is what enforces that, and
it exists because the two failure modes are not symmetric. A key missing from
**every** file fails codegen, loudly, because `nullable-getter: false` means the
getter has to be there. A key missing from **one translation alone** falls back
and nothing breaks. Ten keys have no other assertion anywhere — each of them
needs a state a widget test cannot hold still — and parity is what covers them.
The same test checks that the set of ARB files and the set of codes in
`languages` are the same set.

Adding a language is four edits and one file: the code in `languages`, the
Worker's copy of that list and what it tells the Model to call the language
(`worker/src/language.ts`), the `settingsLanguage*` key naming it in its own
language in **every** ARB file, its case in `languageLabel` and — if its script
has no upper case — `_withoutLetterCase`, both in `lib/on_screen.dart`. Then
the ARB file itself.

`zh` is Simplified Chinese and `pt` is Brazilian Portuguese. The codes carry no
script or region subtag, so the Worker tells the Model which variety to write
beside them.

The other half of the rule is `test/no_english_left_test.dart`, which walks
`lib/` for sentences written outside these files. It says in its own doc comment
how it tells a sentence a user reads from one a user never sees, because the
alternative is an allow list nobody maintains.

**Append only, never reorder.** A new prefix goes at the end of the file; a new
key in an existing prefix goes in that prefix's block, which is not a reorder.
Run `flutter pub get` after either, and check `l10n-untranslated.json` is still
`{}`.

## Dates are not in here

The names of the months, and the order the parts of a date go in, come out of
the CLDR data `flutter_localizations` loads for the locale on the `MaterialApp`.
`asDay`, `asMoment` and the month labels in `on_screen.dart` are the only
callers, and they read the locale off `AppLocalizations.localeName` so there is
still one place a date's house style is decided. Nothing to add here when a
screen starts printing one; a message that *contains* a date takes it as an
already-formatted `String` placeholder.

## What does not get translated

- **Money.** An amount keeps its explicit currency code. A locale would render
  a familiar symbol whatever the actual currency is, and the Home Currency rule
  depends on a foreign-currency Expense looking foreign.
- **Anything transcribed off a receipt** — a merchant's name, a line item as
  printed, a currency code.
- **Slugs, model names and wire keys.** They are not words.
