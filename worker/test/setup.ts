import { fetchMock } from 'cloudflare:test';
import { beforeAll } from 'vitest';

// Nothing reaches the network from a test: Google's signing keys and the model
// are both intercepted, and an unintercepted call fails loudly.
beforeAll(() => {
  fetchMock.activate();
  fetchMock.disableNetConnect();
});
