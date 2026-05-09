const sql = require('mssql');

const config = {
  server: process.env.DB_SERVER,
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  options: {
    encrypt: true,              // required for Azure SQL
    trustServerCertificate: false,
    enableArithAbort: true,
  },
  pool: {
    max: 10,
    min: 0,
    idleTimeoutMillis: 30000,
  },
};

let pool = null;
let connected = false;

async function connect() {
  if (!process.env.DB_SERVER) {
    console.warn('[db] DB_SERVER not set — running without database');
    return;
  }
  try {
    pool = await sql.connect(config);
    connected = true;
    console.log('[db] Connected to Azure SQL');
  } catch (err) {
    console.warn('[db] Could not connect to Azure SQL:', err.message);
    console.warn('[db] Service will start in degraded mode');
  }
}

function getPool() {
  return pool;
}

function isConnected() {
  return connected;
}

module.exports = { connect, getPool, isConnected, sql };
