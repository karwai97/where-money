import { describe, expect, it } from 'vitest';

import currenciesSource from '../../packages/core/lib/src/currencies.dart?raw';
import taxonomySource from '../../packages/core/lib/src/taxonomy.dart?raw';
import { extractionBody, looksLikeBase64 } from '../src/extraction_request';
import { readKnobs } from '../src/knobs';
import { receiptSchema } from '../src/schema';

const knobsFor = (query: string, ceiling = '40') =>
  readKnobs(new URL(`https://worker.test/extract${query}`), ceiling);

const bodyFor = (query: string, image = 'aGVsbG8=', language = 'en') =>
  JSON.parse(extractionBody(image, knobsFor(query), language)) as Record<
    string,
    any
  >;

const dartList = (
  name: string,
  source = taxonomySource,
  file = 'taxonomy.dart',
): string[] => {
  const body = new RegExp(
    'const List<String> ' + name + ' = \\[([^\\]]*)\\]',
  ).exec(source);
  if (!body?.[1]) throw new Error(`No ${name} list in ${file}`);
  return [...body[1].matchAll(/'([^']+)'/g)].map((m) => m[1]!);
};

describe('the receipt schema', () => {
  const nodesOf = (node: any): any[] =>
    node === null || typeof node !== 'object'
      ? []
      : [node, ...Object.values(node).flatMap(nodesOf)];

  const objects = (node: any): any[] =>
    nodesOf(node).filter((each) => each.type === 'object');

  const enumValues = (node: any): string[] =>
    nodesOf(node).flatMap((each) => (Array.isArray(each.enum) ? each.enum : []));

  it('closes every object, because strict mode requires it', () => {
    for (const object of objects(receiptSchema)) {
      expect(object.additionalProperties).toBe(false);
    }
  });

  it('requires every property, because strict mode has no optional fields', () => {
    for (const object of objects(receiptSchema)) {
      expect([...object.required].sort()).toEqual(
        Object.keys(object.properties).sort(),
      );
    }
  });

  it('does not use anyOf at the root, which strict mode rejects', () => {
    expect(receiptSchema).not.toHaveProperty('anyOf');
  });

  it('expresses a field that may be absent as a type union, not an omission', () => {
    expect(receiptSchema.properties.subtotal).toEqual({
      type: ['number', 'null'],
      description: expect.any(String),
    });
  });

  it('offers the Model exactly the Categories the app knows', () => {
    expect(receiptSchema.properties.category.enum).toEqual(
      dartList('categories'),
    );
    expect(receiptSchema.properties.line_items.items.properties.category.enum).toEqual(
      dartList('categories'),
    );
  });

  it('offers the Model exactly the payment methods the app knows', () => {
    expect(receiptSchema.properties.payment_method.enum).toEqual(
      dartList('paymentMethods'),
    );
  });

  it('offers the Model exactly the currencies the app knows, and no code at all for when it cannot tell', () => {
    expect(receiptSchema.properties.currency.enum).toEqual([
      ...dartList('isoCurrencies', currenciesSource, 'currencies.dart'),
      '',
    ]);
  });

  it('offers nothing a receipt prints in place of a code, which is what the enum is for', () => {
    for (const printed of ['RM', '$', 'S$', 'HK$', '£', '€', '¥', '???']) {
      expect(receiptSchema.properties.currency.enum).not.toContain(printed);
    }
  });

  // Strict mode allows 1,000 enum values across the whole schema, and once a
  // schema passes 250 of them their string lengths must total under 15,000.
  // Three letters apiece leaves plenty of room, but the currency enum is the
  // only thing here big enough to ever reach either limit.
  it('stays inside the enum budget strict mode allows a schema', () => {
    const values = enumValues(receiptSchema);

    expect(values.length).toBeLessThan(1000);
    expect(values.join('').length).toBeLessThan(15000);
  });

  it('asks for every field the app reads back', () => {
    expect([...receiptSchema.required].sort()).toEqual(
      [
        'is_receipt',
        'merchant',
        'purchased_at',
        'currency',
        'subtotal',
        'tax',
        'tip',
        'total',
        'payment_method',
        'category',
        'category_reason',
        'line_items',
        'needs_review',
        'review_reasons',
      ].sort(),
    );
  });
});

describe('the request the Worker builds', () => {
  it('sends the image as a data URL the Model can read', () => {
    const body = bodyFor('?media=image/jpeg', 'QUJD');
    const content = body.input[0].content;

    expect(content[0]).toEqual({
      type: 'input_image',
      detail: 'auto',
      image_url: 'data:image/jpeg;base64,QUJD',
    });
    expect(content[1].type).toBe('input_text');
  });

  it('asks for the schema in strict mode', () => {
    expect(bodyFor('').text.format).toEqual({
      type: 'json_schema',
      name: 'receipt_extraction',
      strict: true,
      schema: receiptSchema,
    });
  });

  it('ignores a model the client asked for that is not on the allowlist', () => {
    expect(bodyFor('?model=gpt-4o').model).toBe('gpt-5-nano');
    expect(bodyFor('?model=../../etc/passwd').model).toBe('gpt-5-nano');
  });

  it('honours a model that is on the allowlist', () => {
    expect(bodyFor('?model=gpt-5-mini').model).toBe('gpt-5-mini');
  });

  it('sets the output budget itself, whatever the client asked for', () => {
    expect(bodyFor('?max_output_tokens=2000000').max_output_tokens).toBe(
      bodyFor('').max_output_tokens,
    );
    expect(bodyFor('').max_output_tokens).toBeGreaterThan(0);
  });

  it('tells the API not to keep the receipt', () => {
    expect(bodyFor('').store).toBe(false);
  });

  it('nests reasoning effort where the API wants it', () => {
    expect(bodyFor('?effort=medium').reasoning).toEqual({ effort: 'medium' });
  });

  it('leaves reasoning out entirely when the effort is omit', () => {
    expect(bodyFor('?effort=omit')).not.toHaveProperty('reasoning');
  });

  it('falls back to a known effort when the client asks for an unknown one', () => {
    expect(bodyFor('?effort=maximum').reasoning).toEqual({ effort: 'low' });
  });

  it('carries the language in its instructions, not in anything the image could reach', () => {
    expect(bodyFor('', 'QUJD', 'zh').instructions).toContain(
      'Simplified Chinese',
    );
    expect(bodyFor('', 'QUJD', 'en').instructions).toContain('English');
  });

  // The template is cached, and the language is part of what it templates: two
  // Scans in one isolate asking for different languages must not share one.
  it('does not serve one language the other one instructions', () => {
    const zh = bodyFor('', 'QUJD', 'zh').instructions;
    const en = bodyFor('', 'QUJD', 'en').instructions;

    expect(zh).not.toBe(en);
    expect(bodyFor('', 'QUJD', 'zh').instructions).toBe(zh);
  });

  it('falls back to jpeg when the client names a media type we do not send', () => {
    expect(bodyFor('?media=text/html', 'QUJD').input[0].content[0].image_url).toBe(
      'data:image/jpeg;base64,QUJD',
    );
  });
});

describe('the image the client encoded', () => {
  it('is accepted when it is base64', () => {
    expect(looksLikeBase64('QUJDRA==')).toBe(true);
    expect(looksLikeBase64('QUJD\r\nRA==')).toBe(true);
  });

  it('is refused when it carries anything that could close the JSON string', () => {
    expect(looksLikeBase64('QUJD","model":"gpt-5-pro')).toBe(false);
    expect(looksLikeBase64('QUJD\u0022')).toBe(false);
    expect(looksLikeBase64('')).toBe(false);
  });
});

describe('the daily cap', () => {
  it('is the one the client asked for when it is below the ceiling', () => {
    expect(knobsFor('?cap=5', '40').dailyCap).toBe(5);
  });

  it('is the ceiling when the client asks for more, so a modified client gains nothing', () => {
    expect(knobsFor('?cap=100000', '40').dailyCap).toBe(40);
    expect(knobsFor('', '40').dailyCap).toBe(40);
    expect(knobsFor('?cap=nonsense', '40').dailyCap).toBe(40);
    expect(knobsFor('?cap=-1', '40').dailyCap).toBe(0);
  });

  it('is a real number even when the ceiling in the deployment is not', () => {
    for (const ceiling of ['', 'forty', 'null']) {
      expect(knobsFor('?cap=100000', ceiling).dailyCap).toBeGreaterThan(0);
      expect(knobsFor('?cap=100000', ceiling).dailyCap).toBeLessThan(1000);
    }
  });
});
