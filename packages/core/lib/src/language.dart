/// The languages the app can be read in, and the Model can be asked to write
/// in. Closed on purpose, and for the same reason the spend taxonomy is: both
/// ends of the wire have to agree on it, and a typo must not become a silent
/// new locale. The Worker holds its own copy, as it does for the Knobs.
///
/// Codes only. What a language is called in front of the user is the app's
/// business, and it is called something different in each of them (ADR-0007).
library;

/// ISO 639-1, no script subtag. `zh` therefore cannot distinguish Simplified
/// from Traditional; that was raised and decided, and adding Traditional later
/// means migrating the stored value.
///
/// The order is the order the Settings dropdown offers them in: the two the
/// app started with, then the rest roughly by how many phones read each.
const List<String> languages = [
  'en',
  'zh',
  'es',
  'pt',
  'fr',
  'de',
  'ja',
  'ko',
  'ru',
  'ar',
  'hi',
  'id',
];

/// What a language nobody recognises becomes. A Recap in the wrong language
/// beats no Recap, so neither end of the wire ever refuses one.
const String defaultLanguage = 'en';
