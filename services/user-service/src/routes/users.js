const express = require('express');
const jwt = require('jsonwebtoken');
const { getPool, isConnected, sql } = require('../db');

const router = express.Router();
const JWT_SECRET = process.env.JWT_SECRET || 'dev-secret-change-in-prod';

// Middleware — verify JWT token
function authenticate(req, res, next) {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Missing or invalid Authorization header' });
  }
  try {
    const token = authHeader.split(' ')[1];
    req.user = jwt.verify(token, JWT_SECRET);
    next();
  } catch {
    res.status(401).json({ error: 'Invalid or expired token' });
  }
}

// GET /users/:id  (requires JWT)
router.get('/:id', authenticate, async (req, res) => {
  if (!isConnected()) {
    return res.status(503).json({ error: 'Database not available' });
  }

  try {
    const pool = getPool();
    const result = await pool.request()
      .input('id', sql.Int, parseInt(req.params.id))
      .query('SELECT id, email, name, created_at FROM users WHERE id = @id');

    if (result.recordset.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }

    res.json(result.recordset[0]);
  } catch (err) {
    console.error('[users] get user error:', err.message);
    res.status(500).json({ error: 'Failed to retrieve user' });
  }
});

module.exports = router;
