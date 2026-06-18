const express = require('express');
const { getPayments } = require('../subscriber');

const router = express.Router();

// POST /payments — direct payment request (bypasses Service Bus, for testing)
router.post('/', (req, res) => {
  const { orderId, amount } = req.body;
  if (!orderId || !amount) {
    return res.status(400).json({ error: 'orderId and amount are required' });
  }

  const payment = {
    id: `pay-${Date.now()}`,
    orderId,
    amount,
    status: 'approved',
    processedAt: new Date().toISOString(),
  };

  getPayments().set(orderId, payment);
  res.status(201).json(payment);
});

// GET /payments/:orderId
router.get('/:orderId', (req, res) => {
  const payment = getPayments().get(req.params.orderId);
  if (!payment) return res.status(404).json({ error: 'Payment not found' });
  res.json(payment);
});

module.exports = router;
