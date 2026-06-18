require('dotenv').config();
const { register, metricsMiddleware } = require('./telemetry');
const express = require('express');
const { connect, isConnected } = require('./db');

const app = express();
const PORT = process.env.PORT || 3001;

app.use(express.json());
app.use(metricsMiddleware);

app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

// Health — always available, reports DB connectivity
app.get('/health', (req, res) => {
  res.json({
    status: isConnected() ? 'ok' : 'degraded',
    service: 'user-service',
    db: isConnected() ? 'connected' : 'disconnected',
    timestamp: new Date().toISOString(),
  });
});

// Routes
app.use('/auth', require('./routes/auth'));
app.use('/users', require('./routes/users'));

async function start() {
  await connect();   // warns and continues if DB is unreachable
  app.listen(PORT, () => {
    console.log(`[user-service] listening on port ${PORT}`);
  });
}

start();

module.exports = app;
