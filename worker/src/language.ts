// Which language the Model is told to answer in.
//
// The set is the Worker's own copy of the one in packages/core, the way the
// Knobs allowlists are; a test reads that Dart file and fails if the two
// drift. An unrecognised code falls back to English rather than failing the
// request, because a Recap in the wrong language beats no Recap and a client
// running ahead of a deployed Worker should degrade rather than break.
//
// The instruction text stays here and never crosses the wire. A client that
// could send prompt text is a client that could rewrite the prompt.

export const allowedLanguages = [
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

export const defaultLanguage = 'en';

export function readLanguage(url: URL): string {
  const asked = url.searchParams.get('lang');
  return asked !== null && allowedLanguages.includes(asked)
    ? asked
    : defaultLanguage;
}

// What the Model is told to call the language, which is not what the user is.
// A code carries no script or region subtag, so where the app's own strings
// commit to one, it is named here instead: the `zh` strings are Simplified and
// the `pt` strings are Brazilian, and prose beside them in the other variety
// would read as two languages on one screen.
const modelNames: Record<string, string> = {
  en: 'English',
  zh: 'Simplified Chinese',
  es: 'Spanish',
  pt: 'Brazilian Portuguese',
  fr: 'French',
  de: 'German',
  ja: 'Japanese',
  ko: 'Korean',
  ru: 'Russian',
  ar: 'Arabic',
  hi: 'Hindi',
  id: 'Indonesian',
};

export function languageName(language: string): string {
  return modelNames[language] ?? modelNames[defaultLanguage]!;
}
