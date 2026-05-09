const express = require('express');
const { getPool, isConnected, sql } = require('../db');
const { publishOrderPlaced } = require('../messaging');

const router = express.Router();

// POST /orders
router.post('/', async (req, res) => {
  const { userId, items, totalAmount } = req.body;

  if (!userId || !items || !Array.isArray(items) || items.length === 0 || !totalAmount) {
    return res.status(400).json({ error: 'userId, items (array) and totalAmount are required' });
  }
  if (!isConnected()) return res.status(503).json({ error: 'Database not available' });

  try {
    const pool = getPool();
    const result = await pool.request()
      .input('userId', sql.NVarChar, userId)
      .input('totalAmount', sql.Decimal(10, 2), totalAmount)
      .input('status', sql.NVarChar, 'pending')
      .input('items', sql.NVarChar, JSON.stringify(items))
      .query(`
        INSERT INTO orders (user_id, total_amount, status, items, created_at)
        OUTPUT INSERTED.id
        VALUES (@userId, @totalAmount, @status, @items, GETUTCDATE())
      `);

    const order = { id: result.recordset[0].id, userId, items, totalAmount, status: 'pending' };

    // Publish event asynchronously — don't await, don't let it fail the request
    publishOrderPlaced(order);

    res.status(201).json(order);
  } catch (err) {
    console.error('[orders] create error:', err.message);
    res.status(500).json({ error: 'Failed to create order' });
  }
});

// GET /orders/:userId
router.get('/user/:userId', async (req, res) => {
  if (!isConnected()) return res.status(503).json({ error: 'Database not available' });

  try {
    const pool = getPool();
    const result = await pool.request()
      .input('userId', sql.NVarChar, req.params.userId)
      .query('SELECT id, user_id, total_amount, status, created_at FROM orders WHERE user_id = @userId ORDER BY created_at DESC');

    res.json(result.recordset);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET /orders/:orderId
router.get('/:orderId', async (req, res) => {
  if (!isConnected()) return res.status(503).json({ error: 'Database not available' });

  try {
    const pool = getPool();
    const result = await pool.request()
      .input('id', sql.Int, parseInt(req.params.orderId))
      .query('SELECT id, user_id, total_amount, status, items, created_at FROM orders WHERE id = @id');

    if (result.recordset.length === 0) return res.status(404).json({ error: 'Order not found' });
    res.json(result.recordset[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// PUT /orders/:orderId/status
router.put('/:orderId/status', async (req, res) => {
  const { status } = req.body;
  const validStatuses = ['pending', 'confirmed', 'shipped', 'delivered', 'cancelled'];

  if (!status || !validStatuses.includes(status)) {
    return res.status(400).json({ error: `status must be one of: ${validStatuses.join(', ')}` });
  }
  if (!isConnected()) return res.status(503).json({ error: 'Database not available' });

  try {
    const pool = getPool();
    await pool.request()
      .input('id', sql.Int, parseInt(req.params.orderId))
      .input('status', sql.NVarChar, status)
      .query('UPDATE orders SET status = @status WHERE id = @id');

    res.json({ id: parseInt(req.params.orderId), status });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
