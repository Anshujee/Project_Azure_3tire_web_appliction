const { ServiceBusClient } = require('@azure/service-bus');

let connected = false;

// In-memory store of processed payments (demo only — use a DB in production)
const payments = new Map();

async function startSubscriber() {
  const connStr = process.env.SERVICE_BUS_CONNECTION_STRING;
  const topic = process.env.SERVICE_BUS_ORDERS_TOPIC || 'orders';
  const subscription = process.env.SERVICE_BUS_PAYMENT_SUBSCRIPTION || 'payment-service';

  if (!connStr) {
    console.warn('[subscriber] SERVICE_BUS_CONNECTION_STRING not set — not subscribing');
    return;
  }

  try {
    const client = new ServiceBusClient(connStr);
    const receiver = client.createReceiver(topic, subscription);

    receiver.subscribe({
      async processMessage(message) {
        const { eventType, data } = message.body;
        if (eventType === 'order.placed') {
          console.log(`[payment] Processing payment for order ${data.id}`);

          // Mock: always succeed. Real service would call a payment gateway here.
          const payment = {
            id: `pay-${Date.now()}`,
            orderId: data.id,
            amount: data.totalAmount,
            status: 'approved',
            processedAt: new Date().toISOString(),
          };
          payments.set(data.id, payment);
          console.log(`[payment] Payment ${payment.id} approved for order ${data.id}`);
        }
        await message.complete();  // acknowledge — removes from Service Bus queue
      },
      async processError(err) {
        console.error('[subscriber] Error:', err.message);
      },
    });

    connected = true;
    console.log(`[subscriber] Subscribed to ${topic}/${subscription}`);
  } catch (err) {
    console.warn('[subscriber] Could not connect to Service Bus:', err.message);
  }
}

const getPayments = () => payments;
const isConnected = () => connected;

module.exports = { startSubscriber, getPayments, isConnected };
