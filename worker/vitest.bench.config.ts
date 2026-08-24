import { defineConfig } from 'vitest/config';

// The CPU measurement runs in Node, because a Worker's timers do not advance
// during synchronous execution and so cannot measure it.
export default defineConfig({
  test: { include: ['bench/**/*.test.ts'], environment: 'node' },
});
