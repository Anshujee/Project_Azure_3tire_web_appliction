require('dotenv').config();
const express = require('express');
const { connect, isConnected } = require('./redis');

const app = express();
const PORT = process.env.PORT || 3003;

app.use(express.json());

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
