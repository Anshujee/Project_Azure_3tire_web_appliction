require('dotenv').config();
const express = require('express');
const { connect, isConnected } = require('./db');

const app = express();
const PORT = process.env.PORT || 3001;

app.use(express.json());

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
