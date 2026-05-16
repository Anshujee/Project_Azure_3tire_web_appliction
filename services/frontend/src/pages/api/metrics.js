import { register, collectDefaultMetrics } from 'prom-client';

collectDefaultMetrics({ register });

export default async function handler(req, res) {
  res.setHeader('Content-Type', register.contentType);
  res.end(await register.metrics());
}
