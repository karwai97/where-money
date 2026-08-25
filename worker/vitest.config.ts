import { defineWorkersConfig } from '@cloudflare/vitest-pool-workers/config';

export default defineWorkersConfig({
  test: {
    setupFiles: ['./test/setup.ts'],
    // bench/ runs under `npm run measure` instead, in Node.
    exclude: ['bench/**', 'node_modules/**'],
    poolOptions: {
      workers: {
        wrangler: { configPath: './wrangler.jsonc' },
        miniflare: {
          kvNamespaces: ['MODEL_ALLOWANCE'],
          bindings: {
            OPENAI_API_KEY: 'test-key-not-a-real-one',
            OPENAI_RESPONSES_URL: 'https://api.openai.test/v1/responses',
          },
        },
      },
    },
  },
});
