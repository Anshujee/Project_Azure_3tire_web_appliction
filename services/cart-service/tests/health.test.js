const request = require('supertest');
const app = require('../src/index');

describe('GET /health', () => {
  it('returns 200 with service name', async () => {
    const res = await request(app).get('/health');
    expect(res.statusCode).toBe(200);
    expect(res.body.service).toBe('cart-service');
    expect(['ok', 'degraded']).toContain(res.body.status);
  });
});
