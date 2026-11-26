import { resolveApiBaseUrl } from './config';

describe('resolveApiBaseUrl', () => {
  it('should use the local back when no configuration is provided', () => {
    expect(resolveApiBaseUrl(undefined)).toBe('http://localhost:8080');
    expect(resolveApiBaseUrl({})).toBe('http://localhost:8080');
    expect(resolveApiBaseUrl({ apiBaseUrl: '' })).toBe('http://localhost:8080');
  });

  it('should use the configured address', () => {
    expect(resolveApiBaseUrl({ apiBaseUrl: '/api' })).toBe('/api');
  });
});
