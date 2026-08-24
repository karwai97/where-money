import { defineWorkersConfig } from '@cloudflare/vitest-pool-workers/config';

export default defineWorkersConfig({
  test: {
    setupFiles: ['./test/setup.ts'],
    // bench/ measures CPU, which only Node can do: inside a Worker the clock
    // does not advance during synchronous execution. `npm run measure` runs it.
    exclude: ['bench/**', 'node_modules/**'],
    poolOptions: {
      workers: {
        wrangler: { configPath: './wrangler.jsonc' },
        miniflare: {
          kvNamespaces: ['SCAN_ALLOWANCE'],
          bindings: {
            OPENAI_API_KEY: 'test-key-not-a-real-one',
            OPENAI_RESPONSES_URL: 'https://api.openai.test/v1/responses',
          },
        },
      },
    },
  },
});
