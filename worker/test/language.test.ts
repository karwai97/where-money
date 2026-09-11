// The Worker's copy of the closed set of languages, and the instruction it
// appends. Both halves are the Worker's on purpose: the client sends a code,
// never prompt text.

import { describe, expect, it } from 'vitest';

import languageSource from '../../packages/core/lib/src/language.dart?raw';
import {
  allowedLanguages,
  defaultLanguage,
  languageName,
  readLanguage,
} from '../src/language';

const dartLanguages = (): string[] => {
  const body = /const List<String> languages = \[([^\]]*)\]/.exec(
    languageSource,
  );
  if (!body?.[1]) throw new Error('No languages list in language.dart');
  return [...body[1].matchAll(/'([^']+)'/g)].map((m) => m[1]!);
};

const asked = (query: string) =>
  readLanguage(new URL(`https://worker.test/recap${query}`));

describe('the set of languages the Worker knows', () => {
  it('is exactly the set the app knows', () => {
    expect(allowedLanguages).toEqual(dartLanguages());
  });

  it('falls back to the same language the app does', () => {
    expect(defaultLanguage).toBe(
      /const String defaultLanguage = '([a-z]+)'/.exec(languageSource)?.[1],
    );
  });
});

describe('the language a request asked for', () => {
  it('is honoured when it is one of ours', () => {
    expect(asked('?lang=zh')).toBe('zh');
    expect(asked('?lang=en')).toBe('en');
  });

  it('is English when the client asked for one we do not know', () => {
    expect(asked('?lang=sw')).toBe('en');
    expect(asked('?lang=zh-Hant')).toBe('en');
    expect(asked('?lang=')).toBe('en');
  });

  it('is English when the client did not ask at all', () => {
    expect(asked('')).toBe('en');
  });
});

describe('what the Model is told to write in', () => {
  it('names each language in a way a model would recognise', () => {
    for (const language of allowedLanguages) {
      expect(languageName(language)).toMatch(/^[A-Z][A-Za-z() ]+$/);
    }
  });

  it('names distinct languages distinctly', () => {
    const names = allowedLanguages.map(languageName);
    expect(new Set(names).size).toBe(names.length);
  });

  it('names English for anything it does not know, rather than nothing', () => {
    expect(languageName('kl')).toBe(languageName('en'));
  });
});
