require('dotenv').config();
const { register, metricsMiddleware } = require('./telemetry');
const express = require('express');
const { connect, isConnected } = require('./redis');

const app = express();
const PORT = process.env.PORT || 3003;

app.use(express.json());
app.use(metricsMiddleware);

app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

app.get('/health', (req, res) => {
  res.json({
    status: isConnected() ? 'ok' : 'degraded',
    service: 'cart-service',
    cache: isConnected() ? 'connected' : 'disconnected',
    timestamp: new Date().toISOString(),
  });
});

app.use('/cart', require('./routes/cart'));

async function start() {
  connect();  // non-blocking — warns and continues if Redis unreachable
  app.listen(PORT, () => {
    console.log(`[cart-service] listening on port ${PORT}`);
  });
}

start();

module.exports = app;
