# Phase 3 — Microservices Architecture
> AzureShop DevOps Project | Learning Reference & Interview Prep Guide

---

## What This Phase Covers

In Phase 3 we built the actual application — 8 microservices that together form the AzureShop e-commerce platform. Each service is a small, independent program with a single responsibility. They communicate with each other over HTTP and through an asynchronous message queue (Azure Service Bus).

This phase teaches you how real-world cloud applications are structured, how services talk to each other, how authentication works, and how to build applications that stay running even when their dependencies are unavailable.

---

## Table of Contents

1. [What are Microservices?](#1-what-are-microservices)
2. [Monolith vs Microservices — The Real Trade-off](#2-monolith-vs-microservices--the-real-trade-off)
3. [Our 8 Services — Overview](#3-our-8-services--overview)
4. [The Full Architecture Diagram](#4-the-full-architecture-diagram)
5. [Technology Choices — Why Each Stack](#5-technology-choices--why-each-stack)
6. [Service 1 — user-service (Node.js)](#6-service-1--user-service-nodejs)
7. [Service 2 — product-service (Python/FastAPI)](#7-service-2--product-service-pythonfastapi)
8. [Service 3 — cart-service (Node.js + Redis)](#8-service-3--cart-service-nodejs--redis)
9. [Service 4 — order-service (Node.js + Service Bus)](#9-service-4--order-service-nodejs--service-bus)
10. [Service 5 — payment-service (Node.js + Service Bus)](#10-service-5--payment-service-nodejs--service-bus)
11. [Service 6 — notification-service (Node.js)](#11-service-6--notification-service-nodejs)
12. [Service 7 — frontend (Next.js)](#12-service-7--frontend-nextjs)
13. [Service 8 — api-gateway (NGINX)](#13-service-8--api-gateway-nginx)
14. [The Warn-and-Continue Pattern](#14-the-warn-and-continue-pattern)
15. [JWT Authentication — How It Works](#15-jwt-authentication--how-it-works)
16. [Redis Hash — How Cart Storage Works](#16-redis-hash--how-cart-storage-works)
17. [Azure Service Bus — Async Messaging](#17-azure-service-bus--async-messaging)
18. [API Gateway Rate Limiting](#18-api-gateway-rate-limiting)
19. [FastAPI and Pydantic Validation](#19-fastapi-and-pydantic-validation)
20. [Parameterized SQL Queries — Preventing Injection](#20-parameterized-sql-queries--preventing-injection)
21. [Health Endpoints — Why Every Service Has One](#21-health-endpoints--why-every-service-has-one)
22. [Docker Compose — Local Development](#22-docker-compose--local-development)
23. [Request Lifecycle — End to End](#23-request-lifecycle--end-to-end)
24. [Port Reference and Endpoints](#24-port-reference-and-endpoints)
25. [Interview Questions and Answers](#25-interview-questions-and-answers)

---

## 1. What are Microservices?

### The Simple Definition

A microservice is a small, independently deployable application that does one thing well. Instead of building one giant application that handles users, products, orders, payments, and notifications all together, you build separate small applications — one for each concern.

### The Shopping Mall Analogy

Think of a shopping mall:
- Each shop is independent (a shoe shop, a restaurant, a bookstore)
- Each shop has its own staff, inventory, and opening hours
- If the shoe shop closes for renovation, the restaurant still serves food
- You can expand the restaurant without touching the shoe shop

Now contrast with a market stall where one person sells shoes, food, and books:
- If that person gets sick, everything shuts down
- You cannot scale just the food section — you have to scale everything

Microservices are the shopping mall model. A monolith is the market stall.

---

## 2. Monolith vs Microservices — The Real Trade-off

Understanding this trade-off is crucial for interviews. Neither is always better.

### Monolith — One Big Application

```
AzureShop Monolith (hypothetical)
  ├── User module
  ├── Product module
  ├── Cart module
  ├── Order module
  ├── Payment module
  ├── Notification module
  └── Frontend module
  All in one codebase, one process, one database
```

**Advantages of a monolith:**
- Simple to develop — one codebase, one deployment
- Easy debugging — everything in one place
- No network latency between modules
- Transactions span all data easily (ACID across everything)
- Good for small teams, early-stage products

**Disadvantages of a monolith:**
- A bug in the notification module can crash the entire app including payments
- Scale the whole thing just to serve more products — cannot scale only what needs it
- Deploying a one-line fix requires redeploying 500,000 lines of code
- The codebase grows into a "big ball of mud" — everything depends on everything
- One technology choice for everything — cannot use Python for ML and Node.js for APIs

### Microservices — Many Small Applications

```
AzureShop (what we built)
  user-service      ← only handles user accounts
  product-service   ← only handles product catalog
  cart-service      ← only handles shopping cart
  order-service     ← only handles order creation
  payment-service   ← only handles payment processing
  notification-service ← only sends notifications
  frontend          ← only serves the UI
  api-gateway       ← only routes requests
  Each is independent: own codebase, own process, own database
```

**Advantages of microservices:**
- A crashed notification-service does not affect order-service
- Scale product-service to 20 replicas during a sale without scaling anything else
- Deploy a fix to cart-service without touching the rest
- Each service can use the best technology for its job
- Teams work independently — cart team doesn't need to know how payments work

**Disadvantages of microservices:**
- Network calls between services add latency and can fail
- Distributed transactions are extremely hard (no ACID across services)
- More infrastructure to manage — 8 deployments instead of 1
- Debugging requires tracing requests across multiple services
- Overkill for small teams or simple applications

### Our Choice for AzureShop

We use microservices because this is a learning project for enterprise DevOps. In reality, for an early-stage startup, a monolith would be simpler to start with and refactor later.

---

## 3. Our 8 Services — Overview

| Service | Language | Port | Database | Responsibility |
|---|---|---|---|---|
| user-service | Node.js / Express | 3001 | Azure SQL (`db-users`) | User registration, login, JWT auth |
| product-service | Python / FastAPI | 3002 | Cosmos DB (`products` container) | Product catalog CRUD |
| cart-service | Node.js / Express | 3003 | Redis | Shopping cart add/remove/view |
| order-service | Node.js / Express | 3004 | Azure SQL (`db-orders`) + Service Bus | Create orders, publish events |
| payment-service | Node.js / Express | 3005 | Azure SQL + Service Bus | Process payments, subscribe to events |
| notification-service | Node.js / Express | 3006 | Service Bus only | Subscribe to events, send notifications |
| frontend | Next.js | 3000 | None (calls API Gateway) | Browser UI |
| api-gateway | NGINX | 8080 | None (routes to services) | Entry point, routing, rate limiting |

---

## 4. The Full Architecture Diagram

```
Browser / Mobile App
        ↓ HTTP
  api-gateway (NGINX :8080)
        │ routes by URL path
        ├─→ /api/users/*    → user-service:3001        → Azure SQL (db-users)
        ├─→ /api/products/* → product-service:3002     → Cosmos DB
        ├─→ /api/cart/*     → cart-service:3003        → Redis Cache
        ├─→ /api/orders/*   → order-service:3004       → Azure SQL (db-orders)
        │                                              → Service Bus (publish)
        ├─→ /api/payments/* → payment-service:3005     → Azure SQL
        │                                              → Service Bus (subscribe)
        └─→ /*              → frontend:3000            → (calls api-gateway)

Azure Service Bus (async messaging)
  Topic: orders
    ├── Subscription: payment-service    ← listens for order.placed events
    └── Subscription: notification-service ← listens for order.placed + payment.processed
```

The user never talks directly to user-service, cart-service, etc. All requests go through the API gateway. This is a fundamental pattern — the gateway is the single entry point.

---

## 5. Technology Choices — Why Each Stack

### Node.js / Express — Used by 5 services

Node.js is JavaScript on the server. It is excellent for I/O-heavy services — ones that spend most of their time waiting for database queries or network calls. The `user-service`, `cart-service`, `order-service`, `payment-service`, and `notification-service` are all doing this kind of work: query a database, send a response. Node.js handles many concurrent requests efficiently because it is event-driven and non-blocking.

### Python / FastAPI — Used by product-service

Python is the dominant language for data science and machine learning. In a real e-commerce platform, the product catalog would have recommendation engines, search ranking algorithms, and ML-based features — all in Python. We use FastAPI because it is the modern, high-performance Python web framework with automatic API documentation and Pydantic data validation built in.

### Next.js — Used by frontend

Next.js is a React framework with server-side rendering (SSR). It is one of the most popular ways to build production web applications. It handles routing, API calls, and rendering — giving a fast, SEO-friendly frontend.

### NGINX — Used by api-gateway

NGINX is the world's most widely deployed web server and reverse proxy. We use it as the API gateway because it is purpose-built for routing, load balancing, and rate limiting — it does these things extremely efficiently with minimal resource usage. It is configured via `nginx.conf`, not code.

---

## 6. Service 1 — user-service (Node.js)

### What It Does

Handles everything related to user identity: registration, login, and profile retrieval. It is the service that owns the `users` table in Azure SQL.

### Technology Stack

- **Runtime:** Node.js with Express
- **Database:** Azure SQL (`db-users` database, `users` table)
- **Auth:** bcryptjs for password hashing, jsonwebtoken for JWT

### Key Files

```
services/user-service/
├── src/
│   ├── index.js          ← Express app entry point
│   ├── db.js             ← SQL connection pool
│   └── routes/
│       ├── auth.js       ← POST /auth/register, POST /auth/login
│       └── users.js      ← GET /users/:id, GET /users/profile
├── Dockerfile
└── package.json
```

### API Endpoints

```
POST /auth/register   → body: { email, password, name }
                      → creates user, returns { id, email, name }

POST /auth/login      → body: { email, password }
                      → returns { token: "eyJhbGci..." }

GET  /users/:id       → returns user profile
GET  /health          → returns { status: "ok"|"degraded", db: "connected"|"disconnected" }
```

### How Password Storage Works

Passwords are never stored in plain text. We use bcrypt:

```javascript
// Registration — hash the password before storing
const passwordHash = await bcrypt.hash(password, 10);
// 10 = cost factor — higher = slower hash = harder to brute-force

// Login — compare the provided password against the stored hash
const isValid = await bcrypt.compare(password, storedHash);
// bcrypt.compare handles the salt automatically
```

The number `10` is the bcrypt cost factor. Each increment doubles the computation time. At cost 10, one hash takes ~100ms on a modern machine. An attacker trying to crack passwords via brute force would need ~100ms per attempt — making millions of attempts impractically slow.

### How the SQL Connection Pool Works

```javascript
// db.js
const config = {
  server: process.env.DB_SERVER,
  database: process.env.DB_NAME,
  options: {
    encrypt: true,                              // TLS in transit — always on
    trustServerCertificate: process.env.DB_TRUST_CERT === 'true', // local only
  },
  pool: {
    max: 10,            // max 10 simultaneous connections
    min: 0,             // can scale down to 0 when idle
    idleTimeoutMillis: 30000,   // close idle connections after 30s
  },
};
```

A connection pool keeps several database connections open and reuses them. Opening a new SQL connection takes ~200ms. If every request opened and closed its own connection, a service handling 100 requests/second would spend 20 seconds per second just opening connections. The pool eliminates this — connections are borrowed and returned, not created and destroyed.

`encrypt: true` forces TLS encryption on all data in transit between the service and Azure SQL. Azure SQL always supports TLS. `trustServerCertificate` is only `true` locally (the Docker SQL Server uses a self-signed certificate). In Azure it is `false` — we trust only certificates signed by a proper CA.

---

## 7. Service 2 — product-service (Python/FastAPI)

### What It Does

Manages the product catalog. Products are stored as JSON documents in Cosmos DB. Each product has flexible attributes — a shirt has a size, a laptop has RAM. Cosmos DB's schema-less storage is perfect for this.

### Key Files

```
services/product-service/
├── app/
│   ├── main.py           ← FastAPI app entry point, lifespan handler
│   ├── db.py             ← Cosmos DB connection
│   └── routes/
│       └── products.py   ← GET /products, POST /products, DELETE /products/:id
├── Dockerfile
└── requirements.txt
```

### API Endpoints

```
GET    /products              → list all products
GET    /products?category=Electronics  → filter by category (partition key query)
POST   /products              → body: { name, description, price, categoryId, stock, imageUrl }
DELETE /products/:id          → delete a product
GET    /health                → { status: "ok"|"degraded", db: "connected"|"disconnected" }
```

### The Lifespan Handler

```python
@asynccontextmanager
async def lifespan(app: FastAPI):
    init_db()    # runs once when the server starts
    yield        # server handles requests here
    # cleanup would go after yield (closes connections, etc.)

app = FastAPI(title="Product Service", lifespan=lifespan)
```

FastAPI's `lifespan` replaces the older `@app.on_event("startup")` pattern. It is a context manager — code before `yield` runs at startup, code after `yield` runs at shutdown. We initialize the Cosmos DB connection once at startup so every request can reuse it.

### Cosmos DB Query Pattern

```python
# Efficient query — provides partition key, stays in one partition
items = list(container.query_items(
    query="SELECT * FROM c WHERE c.categoryId = @category",
    parameters=[{"name": "@category", "value": category}],
    partition_key=category,          # ← tells Cosmos which partition to read
))

# Cross-partition query — scans all partitions (used when no category filter)
items = list(container.query_items(
    query="SELECT * FROM c",
    enable_cross_partition_query=True,
))
```

When you provide the partition key, Cosmos DB goes directly to one physical partition — fast and cheap. A cross-partition query scans all partitions in parallel — more expensive in RU/s (Request Units) but necessary when the filter is not the partition key.

---

## 8. Service 3 — cart-service (Node.js + Redis)

### What It Does

Manages the shopping cart. A user's cart is stored in Redis as a Hash. Items can be added, removed, and listed. The cart automatically expires after 7 days.

### Key Files

```
services/cart-service/
├── src/
│   ├── index.js         ← Express app
│   ├── redis.js         ← Redis connection with TLS and retry logic
│   └── routes/
│       └── cart.js      ← GET/POST/DELETE cart operations
├── Dockerfile
└── package.json
```

### API Endpoints

```
GET    /cart/:userId              → list all items in cart
POST   /cart/:userId/items        → add item: { itemId, productId, name, price, quantity }
DELETE /cart/:userId/items/:itemId → remove one item
DELETE /cart/:userId              → clear entire cart
GET    /health
```

### The Redis Connection with TLS

```javascript
const client = new Redis({
  host,
  port: 6380,         // TLS port (6379 is disabled in our Azure Redis)
  password,
  tls: { servername: host },   // TLS enabled by default for Azure

  retryStrategy: (times) => {
    if (times > 3) {
      console.warn('[redis] Max retries reached — running in degraded mode');
      return null;    // stops retrying — service continues without cache
    }
    return Math.min(times * 500, 2000);   // 500ms, 1s, 1.5s, 2s backoff
  },
  lazyConnect: true,    // don't connect until we explicitly call .connect()
});
```

`REDIS_TLS=false` disables TLS when running locally with Docker Compose (local Redis does not have a certificate). In Azure, TLS is always on — port 6380 forces TLS, port 6379 is disabled.

The `retryStrategy` implements exponential backoff — if the connection fails, retry after 500ms, then 1s, then 1.5s, then give up. This avoids hammering a temporarily unavailable Redis with requests every millisecond.

---

## 9. Service 4 — order-service (Node.js + Service Bus)

### What It Does

Creates orders and publishes an `order.placed` event to Azure Service Bus. Other services (payment-service, notification-service) subscribe to this event to do their part without order-service needing to know about them.

### Key Files

```
services/order-service/
├── src/
│   ├── index.js          ← Express app
│   ├── db.js             ← Azure SQL connection
│   ├── messaging.js      ← Service Bus sender
│   └── routes/
│       └── orders.js     ← POST /orders, GET /orders/:id, PUT /orders/:id/status
├── Dockerfile
└── package.json
```

### API Endpoints

```
POST /orders                    → create order: { userId, items, totalAmount }
GET  /orders/:orderId           → get one order
GET  /orders/user/:userId       → get all orders for a user
PUT  /orders/:orderId/status    → update status: { status: "confirmed"|"shipped"|... }
GET  /health
```

### The Fire-and-Forget Event Pattern

```javascript
// routes/orders.js — POST /orders
const order = { id: result.recordset[0].id, userId, items, totalAmount, status: 'pending' };

// Publish event asynchronously — don't await, don't let it fail the HTTP request
publishOrderPlaced(order);

res.status(201).json(order);   // respond immediately to the client
```

Notice: `publishOrderPlaced(order)` is called WITHOUT `await`. The HTTP response returns immediately to the client without waiting for the Service Bus publish to complete.

This is the **fire-and-forget** pattern. The order is already saved in SQL — that is the source of truth. The event is a notification. If Service Bus is temporarily unavailable, the order is still created. The messaging failure is logged but does not fail the request.

```javascript
// messaging.js — publishOrderPlaced
async function publishOrderPlaced(order) {
  if (!connected || !sender) {
    console.warn('[messaging] Skipping event publish — Service Bus not connected');
    return;   // graceful degradation — the order was already saved
  }
  try {
    await sender.sendMessages({
      body: { eventType: 'order.placed', data: order },
      contentType: 'application/json',
      subject: 'order.placed',
    });
  } catch (err) {
    console.error('[messaging] Failed to publish event:', err.message);
    // Do NOT re-throw — a messaging failure should not fail the HTTP request
  }
}
```

---

## 10. Service 5 — payment-service (Node.js + Service Bus)

### What It Does

Two things: handles payment API calls (HTTP), and listens for `order.placed` events from Service Bus. When an order is placed, payment-service receives the event and processes the payment.

### API Endpoints

```
POST /payments                  → process payment: { orderId, userId, amount, method }
GET  /payments/:paymentId       → get payment details
GET  /payments/order/:orderId   → get payment for an order
GET  /health
```

### How It Subscribes to Events

```javascript
// subscriber.js
const receiver = client.createReceiver(topic, subscription);
// topic = "orders", subscription = "payment-service"

receiver.subscribe({
  async processMessage(message) {
    const { eventType, data } = message.body;
    if (eventType === 'order.placed') {
      // auto-process payment for the order
      await processPayment(data);
    }
    await message.complete();   // ACK — tell Service Bus message was processed
  },
  async processError(err) {
    console.error('[payment] Error:', err.message);
    // Service Bus will redeliver unacknowledged messages
  },
});
```

`message.complete()` is critical. Service Bus keeps a message "in flight" until the subscriber either completes it (success) or abandons it (failure → redeliver). If the service crashes before calling `complete()`, Service Bus automatically redelivers the message after a timeout. This guarantees at-least-once delivery.

---

## 11. Service 6 — notification-service (Node.js)

### What It Does

Listens to Service Bus and sends notifications when things happen. Currently it logs to the console (simulating email/SMS sends). In production, this would call SendGrid, Twilio, or Azure Communication Services.

### How It Works

```javascript
// subscriber.js
const handlers = {
  'order.placed': (data) => {
    console.log(`[notify] Order confirmation — user ${data.userId}, order ${data.id}`);
    // production: call SendGrid API to send email
  },
  'payment.processed': (data) => {
    console.log(`[notify] Payment receipt — order ${data.orderId}, status: ${data.status}`);
    // production: call SMS API
  },
};

receiver.subscribe({
  async processMessage(message) {
    const { eventType, data } = message.body;
    const handler = handlers[eventType];
    if (handler) handler(data);
    else console.log(`[notify] Unhandled event type: ${eventType}`);
    await message.complete();
  },
});
```

notification-service subscribes to its own subscription on the `orders` topic. Service Bus fans out: every message published to the topic is delivered to ALL subscriptions. So `order.placed` is received independently by both `payment-service` and `notification-service`.

This is the power of pub/sub: order-service does not know or care who receives its event. It publishes once. New subscribers can be added without touching order-service.

---

## 12. Service 7 — frontend (Next.js)

### What It Does

Serves the browser-facing UI. Users interact with the frontend, which makes API calls to the api-gateway, which routes them to the appropriate microservice.

### Why Next.js?

Next.js is React with additional features:
- **Server-Side Rendering (SSR):** Pages are rendered on the server and sent as HTML. Faster first load, better SEO.
- **File-based routing:** `pages/index.js` = `/`, `pages/products.js` = `/products`. No router configuration needed.
- **API routes:** `pages/api/` can contain lightweight serverless functions if needed.

### How It Calls the Backend

```javascript
// All API calls go to /api/* which the api-gateway routes to the right service
const response = await fetch('/api/products?category=Electronics');
const products = await response.json();
```

From the browser's perspective, all calls go to the same host (`/api/*`). The api-gateway handles routing. The frontend never calls `user-service:3001` directly — it always goes through the gateway.

---

## 13. Service 8 — api-gateway (NGINX)

### What It Does

The api-gateway is the single entry point for all client requests. It:
1. Routes requests to the right service based on URL path
2. Rate limits to prevent abuse
3. Sets headers so backend services know the real client IP
4. Provides a health endpoint

### The nginx.conf — How Routing Works

```nginx
# Define upstream servers — in Kubernetes, these are ClusterIP Service DNS names
upstream user_service    { server user-service:3001; }
upstream product_service { server product-service:3002; }
upstream cart_service    { server cart-service:3003; }
upstream order_service   { server order-service:3004; }
upstream payment_service { server payment-service:3005; }
upstream frontend        { server frontend:3000; }

server {
  listen 8080;

  # Route by URL prefix
  location /api/users/auth/ { proxy_pass http://user_service; }
  location /api/users/      { proxy_pass http://user_service; }
  location /api/products/   { proxy_pass http://product_service; }
  location /api/cart/       { proxy_pass http://cart_service; }
  location /api/orders/     { proxy_pass http://order_service; }
  location /api/payments/   { proxy_pass http://payment_service; }
  location /                { proxy_pass http://frontend; }
}
```

`upstream` blocks define named groups of servers. In Kubernetes, `user-service` resolves via DNS to the ClusterIP Service, which load-balances across all pods. NGINX never knows or cares how many pods are running.

### Header Forwarding

```nginx
proxy_set_header Host            $host;
proxy_set_header X-Real-IP       $remote_addr;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
```

When NGINX forwards a request, the backend service receives the request from NGINX's IP, not the original client's IP. `X-Real-IP` and `X-Forwarded-For` carry the real client IP. Backend services read `req.headers['x-real-ip']` for logging, rate limiting, and security.

---

## 14. The Warn-and-Continue Pattern

This is one of the most important design patterns we use. Every service applies it.

### The Problem

A microservice might need its database to work. If the database is unavailable at startup, what should the service do?

**Bad approach:** Crash. The process exits. Kubernetes restarts it. It crashes again. Loop forever until the database comes back. During this time, no requests are served even if the database is optional for some endpoints.

**Our approach — Warn-and-Continue:**

```javascript
// user-service/src/db.js
async function connect() {
  if (!process.env.DB_SERVER) {
    console.warn('[db] DB_SERVER not set — running without database');
    return;   // no crash — service starts without a database
  }
  try {
    pool = await sql.connect(config);
    connected = true;
    console.log('[db] Connected to Azure SQL');
  } catch (err) {
    console.warn('[db] Could not connect to Azure SQL:', err.message);
    console.warn('[db] Service will start in degraded mode');
    // NO throw — service continues without a database connection
  }
}
```

The service starts regardless. If a request comes in that requires the database:

```javascript
if (!isConnected()) {
  return res.status(503).json({ error: 'Database not available' });
}
// proceed with database operations
```

It returns HTTP 503 (Service Unavailable) for those endpoints. Endpoints that don't need the database (like `/health`) still work.

### Why This Matters in Kubernetes

Kubernetes checks the `readinessProbe` (`/health` endpoint) before sending traffic to a pod. If the service crashes on startup because the database is unavailable, Kubernetes marks the pod as `CrashLoopBackOff` and the probe never succeeds. With warn-and-continue, the pod starts, passes the readiness probe, and serves non-database requests while reporting `"status": "degraded"` in the health check. Kubernetes readiness probe sees `degraded` but 200 OK — the pod receives traffic. When the database comes back, the service reconnects and resumes full functionality.

### product-service Degraded Mode

```python
# main.py
@app.get("/health")
def health():
    return {
        "status": "ok" if is_connected() else "degraded",
        "db": "connected" if is_connected() else "disconnected",
    }
```

In Docker Compose locally, Cosmos DB is not available (no local emulator). product-service starts, reports `"status": "degraded"`, and the other 7 services still work fine. This is intentional — Cosmos DB is hard to run locally, so the product catalog is unavailable but everything else works.

---

## 15. JWT Authentication — How It Works

### What is JWT?

JWT (JSON Web Token) is a standard for passing authentication information between services. After a user logs in, the server issues a token. The client sends this token with every subsequent request. The server verifies the token to identify the user — without a database lookup on every request.

### The Three Parts of a JWT

A JWT looks like: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySWQiOiIxMjMiLCJlbWFpbCI6InRlc3RAZXhhbXBsZS5jb20iLCJpYXQiOjE2MjMwMDAwMDAsImV4cCI6MTYyMzA4NjQwMH0.SomeSignature`

Split by `.`:
1. **Header** (base64): `{"alg":"HS256","typ":"JWT"}` — the signing algorithm
2. **Payload** (base64): `{"userId":"123","email":"test@example.com","iat":...,"exp":...}` — the data
3. **Signature**: HMAC-SHA256(header + "." + payload, secret) — proves authenticity

### How We Use It

```javascript
// auth.js — login
const token = jwt.sign(
  { userId: user.id, email: user.email },   // payload
  JWT_SECRET,                                // secret key
  { expiresIn: '24h' }                       // expiry
);
res.json({ token });
```

```javascript
// Other services verify the token
const decoded = jwt.verify(token, JWT_SECRET);
// decoded = { userId: "123", email: "test@example.com", iat: ..., exp: ... }
// If the token is expired or tampered with, jwt.verify throws an error
```

### Why JWT is Stateless

The server does not store sessions. The token itself contains the user's identity. Any service that knows the `JWT_SECRET` can verify a token without calling the user-service. This scales horizontally — add more user-service replicas without worrying about session state.

### The Security Considerations

- `JWT_SECRET` must be a long random string — never hardcoded in production
- Tokens expire (`expiresIn: '24h'`) — an intercepted token is only valid for limited time
- HTTPS is required — tokens in plain HTTP are visible to anyone on the network
- The payload is base64-encoded, NOT encrypted — never put passwords or sensitive data in the payload

---

## 16. Redis Hash — How Cart Storage Works

### Why Redis for Cart?

A shopping cart has specific characteristics:
- Needs to be very fast (sub-millisecond) — users add/remove items constantly
- Temporary data — if a cart is lost, the user is annoyed but not devastated
- Naturally expires — abandoned carts should not live forever

Redis is an in-memory store — data lives in RAM, not on a disk. This makes it orders of magnitude faster than SQL for reads and writes. It is perfect for session data, caches, and real-time state.

### Redis Hashes — The Data Structure

We use a Redis Hash for each cart. A Hash is like a JavaScript object or a Python dictionary — it maps field names to values.

```
Key:    cart:user-123
Fields: {
  "item-abc": '{"itemId":"item-abc","productId":"prod-1","name":"Laptop","price":999,"quantity":1}',
  "item-def": '{"itemId":"item-def","productId":"prod-2","name":"Mouse","price":29,"quantity":2}',
}
```

Why not a Redis String? A String would store the entire cart as one JSON blob. To add one item, you would need to: GET the whole cart, parse JSON, add the item, serialize to JSON, SET the whole cart. With a Hash, adding one item is a single `HSET` command — atomic and efficient.

### The Cart Implementation

```javascript
const CART_TTL = 7 * 24 * 60 * 60;   // 7 days in seconds

// Add item — POST /cart/:userId/items
const key = `cart:${req.params.userId}`;
const item = { itemId, productId, name, price, quantity, addedAt: new Date().toISOString() };
await getClient().hset(key, itemId, JSON.stringify(item));
await getClient().expire(key, CART_TTL);   // reset 7-day TTL on every add

// Get all items — GET /cart/:userId
const fields = await getClient().hgetall(key);
const items = Object.values(fields).map((v) => JSON.parse(v));

// Remove one item — DELETE /cart/:userId/items/:itemId
await getClient().hdel(key, req.params.itemId);
```

`expire(key, CART_TTL)` resets the TTL to 7 days on every add. If a user is actively shopping, their cart never expires. Only truly abandoned carts (no activity for 7 days) automatically disappear.

---

## 17. Azure Service Bus — Async Messaging

### The Problem With Synchronous Calls

When an order is placed, three things need to happen:
1. Save the order to SQL ← must be synchronous (user is waiting for confirmation)
2. Process payment ← could take 2-3 seconds, user should not wait
3. Send notification email ← user definitely should not wait for this

If order-service called payment-service and notification-service synchronously (HTTP calls), the user would wait 3+ seconds for all of them to complete. Worse, if either service is down, the order would fail — even though the order itself was saved successfully.

### The Solution — Async Messaging with Service Bus

```
order-service                    Service Bus                payment-service
                                 Topic: orders
Creates order in SQL
          ↓
Publishes "order.placed"  ──→   [message queue]   ──→   Receives message
Returns 201 to user        ↑                            Processes payment
(immediately)              │                              
                           └──→   [message queue]   ──→   notification-service
                                                          Sends email
```

The order-service publishes the event and returns immediately. Service Bus delivers the message to subscribers asynchronously. The user gets their response in milliseconds. Payment processing and notification happen in the background.

### Topics and Subscriptions — Fan-out

Service Bus Topics implement the publish-subscribe pattern:

```
Publisher publishes ONE message to topic "orders"
                    ↓
Service Bus copies it to ALL subscriptions:
  ├── Subscription "payment-service"        → payment-service receives its copy
  └── Subscription "notification-service"  → notification-service receives its copy
```

This is called **fan-out**. The publisher sends once, multiple subscribers receive. Adding a new subscriber (say, an analytics-service) requires zero changes to order-service — just create a new subscription.

Compare this to a Queue, where each message is consumed by exactly one receiver. A Queue is for load-balancing work across multiple instances of the same service. A Topic is for broadcasting an event to multiple different services.

### At-Least-Once Delivery

```javascript
receiver.subscribe({
  async processMessage(message) {
    await processPayment(message.body.data);
    await message.complete();   // ← ACK to Service Bus
  },
  async processError(err) {
    // Service Bus will redeliver if complete() was never called
  },
});
```

Service Bus guarantees at-least-once delivery: if a subscriber crashes after receiving a message but before calling `complete()`, Service Bus redelivers the message after a timeout (the message lock expires). This means payment processing might run twice if there is a crash at the wrong moment — which is why payment systems need idempotency checks (checking if the payment already exists before processing).

---

## 18. API Gateway Rate Limiting

Rate limiting prevents a single user (or a bot) from overwhelming the system with requests.

### How NGINX Rate Limiting Works

```nginx
# Define shared memory zones — store rate limit state
limit_req_zone $binary_remote_addr zone=api_limit:10m  rate=60r/m;
limit_req_zone $binary_remote_addr zone=auth_limit:10m rate=10r/m;
```

`$binary_remote_addr` — limit by client IP address (4 bytes binary = compact)
`zone=api_limit:10m` — 10MB of shared memory stores ~160,000 client states
`rate=60r/m` — 60 requests per minute per IP (1 per second)
`rate=10r/m` — 10 requests per minute per IP for auth endpoints (stricter)

```nginx
location /api/users/auth/ {
  limit_req zone=auth_limit burst=5 nodelay;   # stricter — login/register
  proxy_pass http://user_service;
}

location /api/products/ {
  limit_req zone=api_limit burst=30 nodelay;   # generous — browsing products
  proxy_pass http://product_service;
}
```

`burst=5` means a client can "burst" up to 5 extra requests above the rate limit briefly. This handles legitimate usage patterns (a user clicks several pages quickly) without triggering the limiter.

`nodelay` means burst requests are served immediately (not delayed) — but they are counted against the burst budget. Without `nodelay`, NGINX would delay burst requests to smooth them to the rate limit speed.

If the limit is exceeded, NGINX returns **HTTP 429 Too Many Requests**.

### Why Different Limits?

Auth endpoints (login, register) are much stricter (10/min vs 60/min) because:
- Legitimate users rarely log in more than a few times per minute
- Brute-force password attacks try thousands of passwords per minute
- A stricter limit stops brute-force attacks without affecting real users

Product browsing is generous (60/min + burst 30) because:
- A user clicking through a catalog generates many requests quickly
- Blocking legitimate browsing hurts the user experience

---

## 19. FastAPI and Pydantic Validation

FastAPI uses Pydantic to validate incoming request bodies automatically.

### Pydantic Models — Request Validation

```python
class CreateProductRequest(BaseModel):
    name: str
    description: str
    price: float
    categoryId: str    # partition key — required for Cosmos DB
    stock: int
    imageUrl: str = ""  # optional — default is empty string
```

When a POST request arrives with a body, FastAPI automatically:
1. Parses the JSON body
2. Validates each field against the type annotation
3. Returns HTTP 422 Unprocessable Entity if validation fails (with a detailed error message)
4. Passes the validated Pydantic model to the route handler

```python
@router.post("/", response_model=ProductResponse)
async def create_product(product: CreateProductRequest):
    # product is already validated — price is definitely a float, name is definitely a str
    doc = product.model_dump()
    doc["id"] = str(uuid.uuid4())
    container.create_item(body=doc)
    return doc
```

Without Pydantic, you would write `if not request.get("name") or not isinstance(request.get("price"), (int, float)):` manually for every field. Pydantic eliminates all of that boilerplate and gives better error messages.

### response_model — Output Validation

```python
@router.get("/", response_model=list[ProductResponse])
async def list_products():
    ...
```

`response_model=list[ProductResponse]` tells FastAPI to validate and serialize the output. Extra fields in the Cosmos DB document (internal fields, etc.) are stripped. Only fields defined in `ProductResponse` are returned to the client. This prevents accidentally leaking internal data.

### Automatic API Documentation

FastAPI generates interactive API documentation automatically at `/docs` (Swagger UI) and `/redoc`. You get a full, interactive API explorer without writing a single line of documentation code — it is derived from the Pydantic models and route function signatures.

---

## 20. Parameterized SQL Queries — Preventing Injection

SQL injection is one of the most common and most dangerous web vulnerabilities. It happens when user input is directly concatenated into a SQL query.

### The Vulnerable Pattern (NEVER DO THIS)

```javascript
// DANGEROUS — SQL injection vulnerability
const result = await pool.request()
  .query(`SELECT * FROM users WHERE email = '${req.body.email}'`);
// If email = "' OR '1'='1", the query becomes:
// SELECT * FROM users WHERE email = '' OR '1'='1'
// This returns ALL users — authentication bypassed
```

### Our Safe Pattern — Parameterized Queries

```javascript
// SAFE — parameterized query
const result = await pool.request()
  .input('email', sql.NVarChar, email)    // define parameter with type
  .query('SELECT id FROM users WHERE email = @email');  // reference @email
```

The `@email` placeholder is never concatenated into the SQL string. The `mssql` library sends the query and the parameter value separately to SQL Server. SQL Server treats `@email` as a data value, never as SQL code. No matter what the user puts in `email`, it is always treated as a string — not as SQL.

### Why sql.NVarChar Matters

```javascript
.input('email', sql.NVarChar, email)
.input('totalAmount', sql.Decimal(10, 2), totalAmount)
```

Explicit type annotations tell the SQL driver the expected data type. If someone passes a number for `email`, the driver raises a type error before the query runs. This provides a second layer of validation beyond the request body checks.

---

## 21. Health Endpoints — Why Every Service Has One

Every service exposes a `GET /health` endpoint. This is not optional in a Kubernetes environment.

### Why Health Endpoints Exist

Kubernetes needs to know: is this container alive? Is it ready to receive traffic? It cannot read application logs in real-time. It polls the health endpoint instead.

```javascript
// Every service has this pattern
app.get('/health', (req, res) => {
  res.json({
    status: isConnected() ? 'ok' : 'degraded',
    service: 'user-service',
    db: isConnected() ? 'connected' : 'disconnected',
    timestamp: new Date().toISOString(),
  });
});
```

Always returns HTTP 200 — even when degraded. This is intentional. `degraded` means "running but not at full capacity." Kubernetes should still route some traffic (the service handles endpoints that don't need the database). If we returned HTTP 500 when the database was down, Kubernetes would remove the pod from the load balancer entirely.

### How Kubernetes Uses It

Kubernetes has three probe types (all explained in Phase 6):
- **startupProbe:** Is the service done starting up?
- **livenessProbe:** Is the service still alive? (restart if failing)
- **readinessProbe:** Should traffic be sent to this pod? (remove from load balancer if failing)

All three hit `GET /health`. The health endpoint is the contract between your application and the orchestration platform.

### What a Good Health Response Looks Like

```json
{
  "status": "ok",
  "service": "order-service",
  "db": "connected",
  "messaging": "connected",
  "timestamp": "2026-05-12T09:30:00.000Z"
}
```

Multiple dependencies reported separately. An operator looking at the health response immediately sees which dependency is the problem — `"db": "disconnected"` vs `"messaging": "disconnected"` — without digging into logs.

---

## 22. Docker Compose — Local Development

Docker Compose lets you run all 8 services plus local databases with one command.

### The Problem It Solves

To run the application locally without Docker Compose, you would need to:
- Install Node.js and run `npm start` in 6 different terminal windows
- Install Python and run `uvicorn` in another terminal
- Install and configure a local SQL Server
- Install and configure a local Redis
- Remember all the port numbers and environment variables

Docker Compose does all of this with one command: `docker compose up`.

### How It Works

```yaml
# docker-compose.yml (simplified)
services:

  # Local databases (replace Azure services for local dev)
  sqlserver:
    image: mcr.microsoft.com/mssql/server:2022-latest
    environment:
      - SA_PASSWORD=Local@DevPassword1
    healthcheck:
      test: /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "..." -Q "SELECT 1" -C || exit 1
      start_period: 30s   # SQL Server takes ~20s to start

  redis:
    image: redis:7-alpine

  # Application services
  user-service:
    build: ./services/user-service   # builds the Dockerfile
    ports:
      - "3001:3001"                  # host:container
    environment:
      - DB_SERVER=sqlserver          # service name = hostname in Docker network
      - DB_TRUST_CERT=true           # local SQL uses self-signed cert
    depends_on:
      sqlserver:
        condition: service_healthy   # wait until SQL passes health check
```

### The Docker Network

Docker Compose creates a private network for all services. Service names become hostnames:
- `user-service` → resolves to the user-service container's IP
- `sqlserver` → resolves to the SQL Server container's IP
- `redis` → resolves to the Redis container's IP

This is why `DB_SERVER=sqlserver` works — it is the hostname of the SQL Server container. In Azure, `DB_SERVER` would be `sql-azureshop-dev.database.windows.net`.

### The depends_on with Healthcheck

```yaml
depends_on:
  sqlserver:
    condition: service_healthy
```

Without this, user-service might start before SQL Server is ready (SQL Server takes ~20 seconds to initialize). The service would try to connect immediately, fail, and start in degraded mode — even though SQL would be ready 20 seconds later.

`condition: service_healthy` makes user-service wait until SQL Server's healthcheck command (`SELECT 1`) succeeds before starting. This is the correct way to handle startup ordering in Docker Compose.

### Local vs Azure Environment Variables

| Variable | Local (Docker Compose) | Azure (Kubernetes) |
|---|---|---|
| `DB_SERVER` | `sqlserver` (container name) | `sql-azureshop-dev.database.windows.net` |
| `DB_TRUST_CERT` | `true` (self-signed cert) | `false` (Azure has valid cert) |
| `REDIS_HOST` | `redis` (container name) | `redis-azureshop-dev.redis.cache.windows.net` |
| `REDIS_TLS` | `false` (no TLS locally) | `true` (TLS always in Azure) |
| `REDIS_PORT` | `6379` (standard port) | `6380` (TLS port in Azure) |

---

## 23. Request Lifecycle — End to End

Let's trace a complete "add item to cart" request from the user's browser to the database and back.

```
1. User clicks "Add to Cart" in the browser
   Browser sends: POST /api/cart/user-123/items
   Body: { itemId: "item-abc", productId: "prod-1", name: "Laptop", price: 999, quantity: 1 }

2. Request hits api-gateway (NGINX) on port 8080
   NGINX checks rate limit: 60r/m, not exceeded
   NGINX matches location /api/cart/ → proxy_pass http://cart_service
   NGINX forwards to cart-service:3003
   NGINX adds headers: X-Real-IP: <client-ip>, X-Forwarded-For: <client-ip>

3. Request arrives at cart-service
   Express parses the JSON body
   Route handler: POST /cart/:userId/items
   Checks: isConnected() → true (Redis is connected)
   Validates: itemId, productId, name, price, quantity all present

4. cart-service writes to Redis
   Key: cart:user-123
   Command: HSET cart:user-123 item-abc '{"itemId":"item-abc",...}'
   Command: EXPIRE cart:user-123 604800  (reset 7-day TTL)
   Both commands complete in < 1ms

5. cart-service responds
   HTTP 201 Created
   Body: { itemId: "item-abc", productId: "prod-1", name: "Laptop", price: 999, quantity: 1, addedAt: "..." }

6. Response travels back through NGINX to the browser

Total time: ~5ms (dominated by network latency, not processing)
```

Now compare an order placement that triggers async messaging:

```
1. User clicks "Place Order"
   POST /api/orders
   Body: { userId: "user-123", items: [...], totalAmount: 999 }

2. api-gateway routes to order-service:3004

3. order-service inserts into Azure SQL (db-orders)
   INSERT INTO orders (user_id, total_amount, status, items, created_at) → takes ~50ms

4. order-service calls publishOrderPlaced(order) — WITHOUT await
   Returns HTTP 201 to the user immediately (~60ms total)

5. Asynchronously, publishOrderPlaced runs:
   Sends message to Service Bus topic "orders"
   Body: { eventType: "order.placed", data: { id: 1, userId: "user-123", ... } }

6. Service Bus delivers to TWO subscriptions simultaneously:
   → payment-service subscription
   → notification-service subscription

7. payment-service:
   Receives message, processPayment() runs
   Inserts payment record into SQL
   Calls message.complete() → ACKs to Service Bus

8. notification-service:
   Receives message, handler "order.placed" runs
   Logs: "[notify] Order confirmation — user user-123, order 1"
   Calls message.complete()

Steps 5-8 happen after the user already received their "201 Order Created" response.
```

---

## 24. Port Reference and Endpoints

### Port Assignments

| Service | Port | Protocol |
|---|---|---|
| api-gateway | 8080 | HTTP (clients connect here) |
| frontend | 3000 | HTTP |
| user-service | 3001 | HTTP |
| product-service | 3002 | HTTP |
| cart-service | 3003 | HTTP |
| order-service | 3004 | HTTP |
| payment-service | 3005 | HTTP |
| notification-service | 3006 | HTTP |

### Full Endpoint Reference

```
api-gateway (all routes go through here)
  GET  /health                    → gateway health
  POST /api/users/auth/register   → register user
  POST /api/users/auth/login      → login, returns JWT
  GET  /api/users/:id             → get user profile
  GET  /api/products              → list products
  GET  /api/products?category=X   → filter by category
  POST /api/products              → create product
  GET  /api/cart/:userId          → get cart
  POST /api/cart/:userId/items    → add item to cart
  DELETE /api/cart/:userId/items/:itemId → remove item
  POST /api/orders                → place order
  GET  /api/orders/:orderId       → get order
  GET  /api/orders/user/:userId   → orders for a user
  PUT  /api/orders/:orderId/status → update order status
  POST /api/payments              → process payment
  GET  /api/payments/:id          → get payment
  /*   → frontend (Next.js UI)
```

---

## 25. Interview Questions and Answers

### Microservices Fundamentals

**Q: What are microservices and what problem do they solve?**

A: Microservices is an architectural style where an application is built as a collection of small, independently deployable services, each responsible for a specific business capability. They solve problems of monolith applications at scale: (1) fault isolation — a crash in one service does not take down the whole application; (2) independent scaling — scale only the services under load, not everything; (3) independent deployment — deploy a fix to one service without redeploying everything; (4) technology flexibility — each service can use the best language and framework for its job. The trade-offs are increased operational complexity, network latency between services, and the difficulty of distributed transactions.

---

**Q: When would you NOT use microservices?**

A: For small teams, early-stage products, or applications with simple domains. The operational overhead of microservices — multiple deployments, distributed tracing, inter-service communication, network failures — is significant. A monolith is simpler to build, debug, and deploy. Start with a monolith, identify which parts need to scale or deploy independently, and extract those into services when the need is clear. Many successful companies (Shopify, Stack Overflow) run monoliths at large scale. Microservices are a solution to specific scaling and organizational problems, not a default choice.

---

**Q: What is the difference between synchronous and asynchronous communication in microservices?**

A: **Synchronous** (HTTP/REST): Service A calls Service B and waits for the response. Simple to implement, easy to debug, but: if Service B is slow, Service A is slow; if Service B is down, Service A's request fails. **Asynchronous** (message queue): Service A publishes a message and continues immediately. Service B processes the message when it can. Benefits: Service A is not affected by Service B's speed or availability; natural load leveling (messages queue up during traffic spikes); easy to add new consumers without changing the publisher. Drawbacks: harder to debug, no immediate feedback, eventual consistency instead of strong consistency. Use sync for user-facing requests where you need an immediate answer (GET product). Use async for background work where eventual processing is acceptable (send notification email).

---

**Q: What is an API Gateway and why do we need one?**

A: An API gateway is a single entry point for all client requests. Without one, clients need to know the address of every service — 8 different hostnames and ports. If a service moves or its port changes, all clients break. With a gateway: clients talk to one address, the gateway routes to the right service. Additional benefits: centralized rate limiting (one place to prevent abuse), centralized authentication (check JWT once, not in every service), SSL termination (one certificate, not eight), request logging and monitoring in one place. In our project, NGINX serves as the gateway with URL-path-based routing.

---

**Q: What is the publish-subscribe pattern and how does it differ from a queue?**

A: **Queue**: one producer sends messages, one consumer receives each message. Used for distributing work across multiple instances of the same service (load balancing). Each message is processed exactly once. **Pub-Sub (Topics/Subscriptions)**: one publisher sends a message to a topic, multiple different subscribers each receive their own copy. Used for event-driven systems where multiple different services need to react to the same event. In our project, when an order is placed, both payment-service AND notification-service receive the `order.placed` event independently. Adding notification-service required zero changes to order-service — it just subscribed to the existing topic.

---

**Q: What is the warn-and-continue pattern and why is it important?**

A: Warn-and-continue means a service starts and continues operating even if its dependencies (database, cache, message queue) are unavailable at startup. Instead of crashing, it logs a warning and marks itself as "degraded." Requests that require the unavailable dependency return HTTP 503. Requests that don't require it succeed normally. This is important in Kubernetes because: (1) services may start before their dependencies are ready; (2) a temporary database outage should not crash and restart all service instances; (3) services can be health-checked and marked ready for traffic even in degraded state. The alternative — crashing on startup — causes CrashLoopBackOff, which makes recovery slower.

---

**Q: What is JWT and why is it preferred over session tokens for microservices?**

A: JWT (JSON Web Token) is a signed, self-contained token containing user identity claims. The server signs it with a secret; any service that knows the secret can verify it without a database lookup. This is ideal for microservices because: (1) stateless — no shared session store needed between services; (2) horizontally scalable — add more replicas without worrying about session affinity; (3) any service can verify the token independently — the product-service does not need to call the user-service to validate a JWT. The trade-off: JWTs cannot be revoked before expiry (unlike sessions) without additional infrastructure (a token blocklist).

---

### Databases and Data Patterns

**Q: Why do different services use different databases?**

A: This is the **database-per-service** pattern. Each service owns its data store, and no other service accesses it directly. user-service uses SQL for structured, consistent user data with ACID transactions. product-service uses Cosmos DB for flexible JSON documents (different products have different fields). cart-service uses Redis for fast, temporary, in-memory storage with automatic TTL. The benefits: each service can choose the best database for its access patterns; services are truly independent (one service's database schema change does not break others); each can scale independently.

---

**Q: What is a Redis Hash and why use it for cart storage instead of a Redis String?**

A: A Redis Hash stores multiple field-value pairs under one key — like a dictionary. For cart storage: the cart key is `cart:{userId}`, each cart item is a field (keyed by `itemId`), and the value is the serialized item. Benefits over a String: (1) atomic field-level operations — `HSET` adds/updates one item without reading and rewriting the whole cart; (2) `HDEL` removes one item without fetching and modifying the entire cart JSON; (3) `HGETALL` fetches all items in one command. With a String, every add/remove would require GET-parse-modify-serialize-SET — not atomic under concurrent access.

---

**Q: What is SQL injection and how do parameterized queries prevent it?**

A: SQL injection is an attack where malicious SQL code is inserted through user input into a query. For example, if a login query is built as `"SELECT * FROM users WHERE email = '" + email + "'"` and the attacker enters `' OR '1'='1`, the query becomes `SELECT * FROM users WHERE email = '' OR '1'='1'` — returning all users and bypassing authentication. Parameterized queries prevent this by sending the query template and the values separately to the database server. The server treats the value as data, never as SQL syntax. The `mssql` library's `.input('email', sql.NVarChar, email)` + `.query('... WHERE email = @email')` pattern is always safe.

---

**Q: What is Pydantic and what does it do in FastAPI?**

A: Pydantic is a Python library for data validation using type annotations. In FastAPI, you define request body shapes as Pydantic models (classes inheriting from `BaseModel`). When a request arrives, FastAPI automatically validates the body against the model: wrong types → HTTP 422 with a detailed error; missing required fields → HTTP 422; extra fields → ignored (or rejected, depending on config). This eliminates manual validation code. `response_model` applies the same validation to outputs — extra fields from the database are stripped before sending to the client, preventing data leakage.

---

**Q: How does Azure Service Bus guarantee message delivery?**

A: Service Bus uses a message lock mechanism. When a subscriber receives a message, it is locked for a configurable period (default 60 seconds). The message is not visible to other receivers during the lock. The subscriber must call `complete()` to acknowledge successful processing — Service Bus then deletes the message. If the subscriber crashes or the lock expires before `complete()` is called, Service Bus makes the message visible again for redelivery. This guarantees at-least-once delivery. The implication: message handlers must be idempotent — safe to process the same message more than once, because redelivery can happen.

---

**Q: What is the difference between `topics` and `queues` in Azure Service Bus?**

A: A **Queue** delivers each message to exactly one receiver. Multiple receivers compete for messages — this distributes work. Used for task queues and load balancing. A **Topic** delivers each message to all subscribers, each with their own subscription. Each subscription gets its own copy. Used for event-driven architectures where multiple services need to react to the same event. In our project, the `orders` topic has two subscriptions: `payment-service` and `notification-service`. When order-service publishes one `order.placed` message, Service Bus delivers one copy to each subscription.

---

**Q: Why does cart-service set TTL on every add, not just on cart creation?**

A: Setting TTL on every add (not just creation) implements a "sliding expiry" — the cart expires 7 days after the LAST activity, not 7 days after creation. If a user adds something to their cart and returns 6 days later to add another item, the TTL resets to 7 days from that point. Without this, a user who adds items over multiple days might lose their cart while still actively using it. Redis's `EXPIRE` command overwrites any existing TTL, making this easy to implement with one extra command per write.

---

### Architecture and DevOps

**Q: How do services discover each other in our architecture?**

A: In Kubernetes, services discover each other via DNS. Each Kubernetes Service object gets a DNS name equal to its name in the namespace. When NGINX's `nginx.conf` says `server user-service:3001`, NGINX resolves `user-service` via Kubernetes DNS, which returns the ClusterIP of the user-service Service object. The ClusterIP load-balances across all healthy pods. In Docker Compose, the same DNS-based discovery works — Docker creates an internal network where service names are hostnames. Neither NGINX nor the microservices need to know IP addresses — just service names.

---

**Q: What is the health endpoint contract between a service and Kubernetes?**

A: Every service exposes `GET /health` that always returns HTTP 200, even in degraded state. The JSON body reports the status of each dependency. Kubernetes uses this endpoint for three probes: the startup probe (is the app done initializing?), the liveness probe (is the app alive? restart if failing), and the readiness probe (should traffic be sent to this pod? remove from load balancer if failing). Returning HTTP 200 even in degraded state allows Kubernetes to route traffic to endpoints that don't need the failed dependency. Returning HTTP 500 would cause Kubernetes to remove the pod from the load balancer entirely, causing unnecessary downtime.

---

**Q: If the order-service's Service Bus publish fails, does the order get lost?**

A: No. The order is already saved in Azure SQL before the publish attempt. SQL is the source of truth — if the order is in SQL, it exists. The Service Bus publish is a notification, not the record of the order. If the publish fails, the notification is lost — payment and notification won't happen automatically. In production, this would be handled by an outbox pattern: the event is saved in the same SQL transaction as the order, and a background process reads the outbox and publishes to Service Bus with retry logic. This guarantees that if the order is saved, the event will eventually be published — even if Service Bus was down at the time of the order.

---
