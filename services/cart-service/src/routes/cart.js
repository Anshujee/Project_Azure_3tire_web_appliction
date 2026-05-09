const express = require('express');
const { getClient, isConnected } = require('../redis');

const router = express.Router();
const CART_TTL = 7 * 24 * 60 * 60; // 7 days in seconds — matches Cosmos DB cart TTL

// Cart is stored as a Redis hash: key = cart:{userId}, field = itemId, value = JSON item

// GET /cart/:userId
router.get('/:userId', async (req, res) => {
  if (!isConnected()) return res.status(503).json({ error: 'Cache not available' });

  try {
    const key = `cart:${req.params.userId}`;
    const fields = await getClient().hgetall(key);

    if (!fields) return res.json({ userId: req.params.userId, items: [] });

    const items = Object.values(fields).map((v) => JSON.parse(v));
    res.json({ userId: req.params.userId, items });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /cart/:userId/items  — body: { itemId, productId, name, price, quantity }
router.post('/:userId/items', async (req, res) => {
  if (!isConnected()) return res.status(503).json({ error: 'Cache not available' });

  const { itemId, productId, name, price, quantity } = req.body;
  if (!itemId || !productId || !name || price == null || !quantity) {
    return res.status(400).json({ error: 'itemId, productId, name, price, quantity are required' });
  }

  try {
    const key = `cart:${req.params.userId}`;
    const item = { itemId, productId, name, price, quantity, addedAt: new Date().toISOString() };

    await getClient().hset(key, itemId, JSON.stringify(item));
    await getClient().expire(key, CART_TTL);  // reset TTL on every add

    res.status(201).json(item);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// DELETE /cart/:userId/items/:itemId
router.delete('/:userId/items/:itemId', async (req, res) => {
  if (!isConnected()) return res.status(503).json({ error: 'Cache not available' });

  try {
    const key = `cart:${req.params.userId}`;
    await getClient().hdel(key, req.params.itemId);
    res.status(204).send();
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// DELETE /cart/:userId  — clear entire cart
router.delete('/:userId', async (req, res) => {
  if (!isConnected()) return res.status(503).json({ error: 'Cache not available' });

  try {
    await getClient().del(`cart:${req.params.userId}`);
    res.status(204).send();
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
