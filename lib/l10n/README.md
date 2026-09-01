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

## Messages, not fragments

A sentence is one key, placeholders included. Concatenating a translated
fragment onto a number does not survive a second language — the number goes
somewhere else in the sentence, and the plural rule is not English's.

```
"settingsScansDailyCap": "{count, plural, =1{Daily cap: 1 Scan} other{Daily cap: {count} Scans}}"
```

Chinese has one plural form, so its version of a plural message carries `other`
alone. That is correct, not a missing translation.

## Both files are hand-written

Every key exists in every ARB file, in real prose. `l10n.yaml` writes anything
missing to `l10n-untranslated.json`, and that file should stay empty — a key
that silently falls back to English is a screen that is half migrated and
looks finished.

## What does not get translated

- **Money.** An amount keeps its explicit currency code. A locale would render
  a familiar symbol whatever the actual currency is, and the Home Currency rule
  depends on a foreign-currency Expense looking foreign.
- **Anything transcribed off a receipt** — a merchant's name, a line item as
  printed, a currency code.
- **Slugs, model names and wire keys.** They are not words.
