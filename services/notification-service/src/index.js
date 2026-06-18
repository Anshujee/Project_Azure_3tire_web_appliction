require('dotenv').config();
const { register, metricsMiddleware } = require('./telemetry');
const express = require('express');
const { startSubscriber, isConnected } = require('./subscriber');

const app = express();
const PORT = process.env.PORT || 3006;

app.use(express.json());
app.use(metricsMiddleware);

app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    service: 'notification-service',
    messaging: isConnected() ? 'connected' : 'disconnected',
    timestamp: new Date().toISOString(),
  });
});

async function start() {
  await startSubscriber();
  app.listen(PORT, () => console.log(`[notification-service] listening on port ${PORT}`));
}

start();

module.exports = app;
