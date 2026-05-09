require('dotenv').config();
const express = require('express');
const { startSubscriber, isConnected } = require('./subscriber');

const app = express();
const PORT = process.env.PORT || 3005;

app.use(express.json());

app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    service: 'payment-service',
    messaging: isConnected() ? 'connected' : 'disconnected',
    timestamp: new Date().toISOString(),
  });
});

app.use('/payments', require('./routes/payments'));

async function start() {
  await startSubscriber();
  app.listen(PORT, () => console.log(`[payment-service] listening on port ${PORT}`));
}

start();

module.exports = app;
