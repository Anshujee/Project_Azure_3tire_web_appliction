require('dotenv').config();
const express = require('express');
const { connect: connectDb, isConnected: dbConnected } = require('./db');
const { connect: connectMessaging, isConnected: msgConnected } = require('./messaging');

const app = express();
const PORT = process.env.PORT || 3004;

app.use(express.json());

app.get('/health', (req, res) => {
  res.json({
    status: dbConnected() ? 'ok' : 'degraded',
    service: 'order-service',
    db: dbConnected() ? 'connected' : 'disconnected',
    messaging: msgConnected() ? 'connected' : 'disconnected',
    timestamp: new Date().toISOString(),
  });
});

app.use('/orders', require('./routes/orders'));

async function start() {
  await connectDb();
  await connectMessaging();
  app.listen(PORT, () => console.log(`[order-service] listening on port ${PORT}`));
}

start();

module.exports = app;
