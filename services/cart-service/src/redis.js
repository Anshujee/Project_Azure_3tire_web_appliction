const Redis = require('ioredis');

let client = null;
let connected = false;

function connect() {
  const host = process.env.REDIS_HOST;
  const port = process.env.REDIS_PORT || 6380;
  const password = process.env.REDIS_PASSWORD;

  if (!host) {
    console.warn('[redis] REDIS_HOST not set — running without cache');
    return;
  }

  client = new Redis({
    host,
    port: parseInt(port),
    password,
    tls: { servername: host },  // Azure Redis requires TLS on port 6380
    retryStrategy: (times) => {
      // Retry up to 3 times with exponential backoff, then give up
      if (times > 3) {
        console.warn('[redis] Max retries reached — running in degraded mode');
        return null;  // stops retrying
      }
      return Math.min(times * 500, 2000);
    },
    lazyConnect: true,          // don't connect until we call .connect()
  });

  client.on('connect', () => {
    connected = true;
    console.log('[redis] Connected to Azure Redis Cache');
  });

  client.on('error', (err) => {
    connected = false;
    console.warn('[redis] Connection error:', err.message);
  });

  client.connect().catch((err) => {
    console.warn('[redis] Could not connect:', err.message);
    console.warn('[redis] Service will start in degraded mode');
  });
}

function getClient() {
  return client;
}

function isConnected() {
  return connected;
}

module.exports = { connect, getClient, isConnected };
