const { ServiceBusClient } = require('@azure/service-bus');

let sbClient = null;
let sender = null;
let connected = false;

async function connect() {
  const connStr = process.env.SERVICE_BUS_CONNECTION_STRING;
  const topic = process.env.SERVICE_BUS_ORDERS_TOPIC || 'orders';

  if (!connStr) {
    console.warn('[messaging] SERVICE_BUS_CONNECTION_STRING not set — events will not be published');
    return;
  }

  try {
    sbClient = new ServiceBusClient(connStr);
    sender = sbClient.createSender(topic);
    connected = true;
    console.log(`[messaging] Connected to Service Bus topic: ${topic}`);
  } catch (err) {
    console.warn('[messaging] Could not connect to Service Bus:', err.message);
  }
}

// Publish an order.placed event — fire-and-forget, does not block the HTTP response
async function publishOrderPlaced(order) {
  if (!connected || !sender) {
    console.warn('[messaging] Skipping event publish — Service Bus not connected');
    return;
  }

  try {
    await sender.sendMessages({
      body: { eventType: 'order.placed', data: order },
      contentType: 'application/json',
      subject: 'order.placed',
    });
    console.log(`[messaging] Published order.placed for order ${order.id}`);
  } catch (err) {
    // Log but don't throw — a messaging failure should not fail the HTTP request
    console.error('[messaging] Failed to publish event:', err.message);
  }
}

const isConnected = () => connected;

module.exports = { connect, publishOrderPlaced, isConnected };
