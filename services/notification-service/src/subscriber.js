const { ServiceBusClient } = require('@azure/service-bus');

let connected = false;

// Handlers for each event type
const handlers = {
  'order.placed': (data) => {
    console.log(`[notify] 📧 Order confirmation — user ${data.userId}, order ${data.id}, total $${data.totalAmount}`);
  },
  'payment.processed': (data) => {
    console.log(`[notify] 📧 Payment receipt — order ${data.orderId}, status: ${data.status}`);
  },
};

async function startSubscriber() {
  const connStr = process.env.SERVICE_BUS_CONNECTION_STRING;
  const topic = process.env.SERVICE_BUS_ORDERS_TOPIC || 'orders';
  const subscription = process.env.SERVICE_BUS_NOTIFICATION_SUBSCRIPTION || 'notification-service';

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
        const handler = handlers[eventType];
        if (handler) {
          handler(data);
        } else {
          console.log(`[notify] Unhandled event type: ${eventType}`);
        }
        await message.complete();
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

const isConnected = () => connected;

module.exports = { startSubscriber, isConnected };
