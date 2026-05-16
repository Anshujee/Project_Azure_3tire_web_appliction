# Phase 3 — Microservices Architecture: Question Bank

All questions asked during revision, with full detailed answers.
Covers: microservices vs monolith, sync vs async communication, API gateway, pub-sub vs queue, warn-and-continue, JWT, database-per-service, Redis Hash, SQL injection, parameterized queries, Azure Service Bus, Pydantic, outbox pattern.

---

## Table of Contents

1. [What Are Microservices and What Problem Do They Solve?](#q1-what-are-microservices-and-what-problem-do-they-solve)
2. [When Would You NOT Use Microservices?](#q2-when-would-you-not-use-microservices)
3. [What is the Difference Between Synchronous and Asynchronous Communication?](#q3-what-is-the-difference-between-synchronous-and-asynchronous-communication)
4. [What is an API Gateway and Why Do We Need One?](#q4-what-is-an-api-gateway-and-why-do-we-need-one)
5. [What is the Publish-Subscribe Pattern and How Does It Differ from a Queue?](#q5-what-is-the-publish-subscribe-pattern-and-how-does-it-differ-from-a-queue)
6. [What is the Warn-and-Continue Pattern and Why is it Important?](#q6-what-is-the-warn-and-continue-pattern-and-why-is-it-important)
7. [What is JWT and Why is it Preferred Over Session Tokens for Microservices?](#q7-what-is-jwt-and-why-is-it-preferred-over-session-tokens-for-microservices)
8. [Why Do Different Services Use Different Databases?](#q8-why-do-different-services-use-different-databases)
9. [What is a Redis Hash and Why Use It for Cart Storage?](#q9-what-is-a-redis-hash-and-why-use-it-for-cart-storage)
10. [What is SQL Injection and How Do Parameterized Queries Prevent It?](#q10-what-is-sql-injection-and-how-do-parameterized-queries-prevent-it)

---

## Q1. What Are Microservices and What Problem Do They Solve?

### The Simple Definition

Microservices is an architectural style where an application is built as a collection of **small, independently deployable services**, each responsible for a single business capability.

AzureShop is split into 8 services: user, product, cart, order, payment, notification, api-gateway, frontend. Each runs as its own process in its own container.

### The Problem They Solve — Monolith at Scale

When one big application handles everything:

| Problem | What happens |
|---|---|
| One bug crashes everything | A payment bug takes down the user login page too |
| Can't scale selectively | Black Friday spikes on product-service force you to scale the entire app |
| Deploy everything for any change | Fixing a typo in the notification email requires redeploying all 50,000 lines |
| Technology locked in | You chose Node.js on day 1, now you're stuck using it for everything |

### What Microservices Give You

1. **Fault isolation** — a crash in notification-service does not affect user-service or checkout
2. **Independent scaling** — Black Friday? Scale product-service and cart-service only
3. **Independent deployment** — fix the notification email template, deploy notification-service alone
4. **Technology flexibility** — product-service uses Python/FastAPI for Cosmos DB's SDK, others use Node.js

### The Trade-offs (Say These in Interviews)

- **Increased operational complexity** — 8 deployments, 8 health checks, 8 log streams to manage
- **Network latency** — a checkout that was one function call is now 3–4 HTTP requests across the network
- **Distributed transactions** — rolling back a failed order across SQL, Service Bus, and Redis is hard
- **Harder debugging** — a single user request touches 4 services; you need distributed tracing to follow it

### In AzureShop

```
User clicks "Buy"
  → frontend (Next.js)
  → api-gateway (NGINX) routes to order-service
  → order-service saves to Azure SQL
  → order-service publishes to Azure Service Bus
  → payment-service subscribes, charges card
  → notification-service subscribes, sends email
```

Five services involved in one user action. Each can fail or be updated independently.

---

## Q2. When Would You NOT Use Microservices?

### The Honest Answer

Microservices are a solution to specific scaling and organisational problems — not a default choice. Many successful companies run monoliths at scale (Shopify, Stack Overflow).

### When a Monolith is Better

| Situation | Why monolith wins |
|---|---|
| Small team (1–5 devs) | Microservices require DevOps expertise most small teams don't have |
| Early-stage product | Requirements change constantly; refactoring a monolith is easier than reorganising services |
| Simple domain | If services would just call each other for every operation, you've added network latency with no benefit |
| Low traffic | Scaling a single process is simpler and cheaper than orchestrating 8 containers |

### The Rule of Thumb

Start with a modular monolith. When you identify that:
- One module needs to scale 10× independently
- One module needs a completely different technology stack
- Multiple teams are stepping on each other deploying the same codebase

...extract that module into a service. This is the **strangler fig pattern** — gradually migrate pieces without a big-bang rewrite.

### What AzureShop Would Look Like as a Monolith

A single Node.js app with separate route files for users, products, cart, orders. One deployment, one database connection, function calls instead of HTTP calls. Simpler to build, harder to scale independently.

We split it into microservices for **learning purposes** — to build and deploy real-world DevOps patterns at each stage.

---

## Q3. What is the Difference Between Synchronous and Asynchronous Communication?

### Synchronous (HTTP/REST) — Caller Waits

```
order-service ──HTTP POST──→ payment-service
              ←──200 OK────
```

Order-service blocks until payment-service responds. If payment-service is slow → order-service is slow. If payment-service is down → order-service request fails.

**Used for:** User-facing requests where you need an immediate answer. `GET /products/123` must return product data now.

### Asynchronous (Message Queue) — Fire and Forget

```
order-service ──publish──→ [Azure Service Bus topic: orders]
                                      ↓ (later)
                          payment-service reads message
                          notification-service reads message
```

Order-service publishes and continues immediately. Payment-service processes when it's ready. If payment-service is temporarily down, messages queue up and are processed on recovery.

**Used for:** Background work where eventual processing is acceptable. Sending a notification email does not need to happen in the same HTTP request that creates the order.

### Comparison Table

| | Synchronous (HTTP) | Asynchronous (Service Bus) |
|---|---|---|
| Caller behaviour | Blocks waiting for response | Continues immediately |
| Failure impact | Caller fails if callee is down | Messages queue up, processed on recovery |
| Debugging | Easy — one request, one trace | Harder — message may be processed minutes later |
| Consistency | Strong (immediate) | Eventual |
| Best for | User-facing reads/writes | Background events, notifications, payments |

### In AzureShop

- **Synchronous:** NGINX → user-service (login), NGINX → product-service (browse), NGINX → cart-service (add item)
- **Asynchronous:** order-service → Service Bus → payment-service + notification-service

The order is saved to SQL immediately (sync). The payment and email happen in the background (async). The user gets "Order placed" instantly, then an email a few seconds later.

---

## Q4. What is an API Gateway and Why Do We Need One?

### The Problem Without a Gateway

```
Browser doesn't know where each service is:
  user login   → user-service:3001 ?
  browse shop  → product-service:3005 ?
  view cart    → cart-service:3002 ?
```

8 different hostnames and ports. If user-service moves to port 3010, every client that hardcodes 3001 breaks.

### The Solution — One Entry Point

```
Browser
  ↓
api-gateway:80  (NGINX)
  ├── /api/users/*     → user-service:3001
  ├── /api/products/*  → product-service:3005
  ├── /api/cart/*      → cart-service:3002
  ├── /api/orders/*    → order-service:3003
  └── /*               → frontend:3000
```

Clients only talk to one address. Service locations are internal configuration, invisible to clients.

### Additional Benefits

| Benefit | What it means |
|---|---|
| Single TLS certificate | One HTTPS cert at the gateway, services talk plain HTTP internally |
| Centralized rate limiting | One place to limit requests per IP, preventing abuse |
| Centralized auth | Verify JWT once at the gateway, not in every service |
| Request logging | All traffic flows through one point, one log stream |
| SSL termination | Decryption happens once; internal traffic stays fast |

### In AzureShop

Our api-gateway is **NGINX** with `nginx.conf` routing rules. In Kubernetes, NGINX forwards to Kubernetes Service DNS names — `proxy_pass http://user-service:3001` resolves via CoreDNS to the ClusterIP of the user-service Service object, which then load-balances across all healthy user-service pods.

---

## Q5. What is the Publish-Subscribe Pattern and How Does It Differ from a Queue?

### Queue — One Producer, One Consumer

```
producer → [queue] → consumer-instance-1
                  ↘ consumer-instance-2
                  ↘ consumer-instance-3
```

Each message is delivered to **exactly one** consumer. Multiple consumers compete for messages — this is load balancing. If 100 messages arrive and you have 3 workers, each worker processes roughly 33.

**Use case:** distributing work across multiple instances of the same service. Task queues.

### Pub-Sub (Topic + Subscriptions) — One Publisher, Many Consumers

```
publisher → [topic] → subscription-A → payment-service (gets its own copy)
                    → subscription-B → notification-service (gets its own copy)
```

Each subscription gets its **own independent copy** of every message. Adding a new consumer requires only creating a new subscription — zero changes to the publisher.

**Use case:** event-driven systems where multiple different services react to the same event.

### In AzureShop

```
order-service publishes ONE message to [orders topic]

Azure Service Bus delivers:
  → Copy 1 to [orders/payment-subscription] → payment-service
  → Copy 2 to [orders/notification-subscription] → notification-service
```

When we added notification-service, order-service code was **not touched** — we only created a new subscription on the existing topic.

### Queue vs Topic Summary

| | Queue | Topic + Subscriptions |
|---|---|---|
| Message delivery | Exactly one receiver | All subscribers get a copy |
| Use case | Work distribution (load balance) | Event fanout (multiple reactions) |
| Adding a consumer | Compete with existing consumers | Add new subscription, zero publisher change |
| AzureShop usage | Not used directly | `orders` topic → payment + notification |

---

## Q6. What is the Warn-and-Continue Pattern and Why is it Important?

### The Problem

Services have dependencies — databases, Redis, Service Bus. What should a service do if a dependency is unavailable at startup?

**Option A — Crash on startup:**
```
cart-service starts → Redis unreachable → process exits → CrashLoopBackOff
```
Kubernetes keeps restarting the pod with exponential backoff. Recovery takes minutes, and it cannot serve any requests even for paths that don't need Redis.

**Option B — Warn and continue (what we build):**
```
cart-service starts → Redis unreachable → log WARNING → mark as "degraded"
  → GET /health returns 200 with { redis: "unavailable" }
  → GET /cart returns 503 (Redis needed)
  → GET /health itself still works
  → When Redis recovers, next request reconnects automatically
```

### Why Kubernetes Needs This

1. **Services start before dependencies are ready.** In a fresh cluster, Redis might still be initialising when cart-service tries to connect.
2. **Temporary outages should not cascade.** A 30-second Redis blip should not cause CrashLoopBackOff on all cart-service instances.
3. **Partial degradation is better than total outage.** A user can still browse products (product-service doesn't need Redis) even if cart is temporarily down.

### The Health Endpoint Contract

Every AzureShop service exposes `GET /health` that returns HTTP 200 **always**, even in degraded state:

```json
{
  "status": "degraded",
  "redis": "unavailable",
  "uptime": 42.3
}
```

Kubernetes uses this for three probes:
- **Startup probe** — has the app finished initialising?
- **Liveness probe** — is the process alive? (restart if failing)
- **Readiness probe** — should traffic be sent here? (remove from load balancer if failing)

Returning 200 (even degraded) keeps the pod in the load balancer for requests it CAN handle. Returning 500 would remove the pod entirely.

---

## Q7. What is JWT and Why is it Preferred Over Session Tokens for Microservices?

### Session Tokens (Traditional)

```
1. User logs in → server creates session in database
2. Server returns session ID cookie: "abc123"
3. Every request: server looks up "abc123" in session DB
4. If session found and valid → authorised
```

Problem: every service needs access to the session database. In microservices with 8 services, that's 8 database connections to a shared session store. Scaling adds complexity.

### JWT (JSON Web Token)

```
1. User logs in → server creates JWT with claims: { userId: 42, role: "user" }
2. Server SIGNS the JWT with a secret key → sends it to client
3. Every request: client sends JWT in Authorization header
4. Any service that knows the secret can VERIFY the JWT without a database lookup
```

### JWT Structure

```
eyJhbGciOiJIUzI1NiJ9.eyJ1c2VySWQiOjQyfQ.signature
    header (base64)      payload (base64)    HMAC signature
```

The signature proves the payload wasn't tampered with. Decode it anywhere, verify the signature, extract the claims.

### Why JWT is Better for Microservices

| | Session Tokens | JWT |
|---|---|---|
| State | Stored in database | Self-contained — no lookup needed |
| Scalability | All services need session DB access | Any service can verify with just the secret |
| Horizontal scaling | Session affinity needed (or shared store) | Stateless — any instance can verify |
| Verification | Database query per request | Cryptographic signature check (fast, offline) |

### The Trade-off

JWTs cannot be revoked before expiry without additional infrastructure (a blocklist). A stolen JWT is valid until it expires. Session tokens can be deleted from the database immediately. In AzureShop, short expiry times (e.g. 1 hour) and HTTPS mitigate this risk.

---

## Q8. Why Do Different Services Use Different Databases?

### The Database-Per-Service Pattern

Each service owns its data store exclusively. No other service accesses it directly — only through the owning service's API.

### AzureShop Database Choices

| Service | Database | Why |
|---|---|---|
| user-service | Azure SQL | Structured user records, ACID transactions, relational joins for user data |
| product-service | Cosmos DB | Flexible JSON documents — different products have different fields (a TV has screen size, a shirt has size/colour) |
| cart-service | Redis | Fast in-memory reads/writes, automatic TTL (carts expire after 7 days), no persistence needed |
| order-service | Azure SQL | Transactional integrity — orders must never be partially saved |
| payment-service | Azure SQL (via order-service) | Payment records tied to orders, needs ACID guarantees |

### Why Not One Shared Database?

If all services share one database:
- Schema change in user-service breaks product-service queries
- Cart-service's high-frequency writes slow down order-service reads
- All services must be updated and redeployed together for any schema migration
- One database is a single point of failure for everything

With database-per-service:
- user-service can migrate its schema without touching anything else
- Redis can be scaled independently for cart workloads
- A Redis outage only affects cart, not orders or users

### The Trade-off

Cross-service joins are impossible at the database level — you must join in application code (call user-service API to get user data, join with order data in memory). This is a deliberate constraint that enforces service boundaries.

---

## Q9. What is a Redis Hash and Why Use It for Cart Storage?

### What Redis Supports

Redis is not just a key-value store for strings. It supports several data structures: Strings, Lists, Sets, Sorted Sets, and **Hashes**.

### Redis Hash — A Dictionary Under One Key

```
key: "cart:user42"
  ├── field: "item:prod-001"  value: '{"name":"Laptop","qty":1,"price":999}'
  ├── field: "item:prod-007"  value: '{"name":"Mouse","qty":2,"price":29}'
  └── field: "item:prod-023"  value: '{"name":"Keyboard","qty":1,"price":79}'
```

The cart is one Redis key. Each item in the cart is one field in the Hash.

### Why Hash, Not String?

**If you stored the whole cart as a JSON string:**
```
GET cart:user42          → parse JSON → modify → serialize → SET cart:user42
```
Adding one item requires reading the entire cart, modifying in memory, and writing back. Under concurrent access, two simultaneous adds could overwrite each other (race condition).

**With a Hash:**
```
HSET cart:user42 item:prod-001 '{"qty":1,...}'    → adds/updates one field atomically
HDEL cart:user42 item:prod-007                     → removes one field atomically
HGETALL cart:user42                                → fetches all items in one command
```

Each operation is atomic and affects only the target field. No read-modify-write cycle needed.

### The Sliding TTL Trick

We call `EXPIRE cart:user42 604800` (7 days in seconds) on **every write**, not just on cart creation. This implements sliding expiry — the cart expires 7 days after the **last activity**, not 7 days after creation. A user who adds items on day 1 and returns on day 6 to add another item will have their cart for 7 more days from day 6. Without resetting TTL on every write, the cart would expire during active use.

---

## Q10. What is SQL Injection and How Do Parameterized Queries Prevent It?

### The Attack

SQL injection exploits string concatenation in query building:

```javascript
// DANGEROUS — never do this
const query = "SELECT * FROM users WHERE email = '" + email + "'";
```

If the attacker enters `' OR '1'='1` as the email:
```sql
SELECT * FROM users WHERE email = '' OR '1'='1'
```
This returns ALL users — bypassing authentication. They logged in as everyone.

More destructive:
```
email = "'; DROP TABLE users; --"
```
```sql
SELECT * FROM users WHERE email = ''; DROP TABLE users; --'
```
The entire users table is deleted.

### Parameterized Queries — The Fix

```javascript
// SAFE — parameterized query
const result = await pool.request()
  .input('email', sql.NVarChar, email)
  .query('SELECT * FROM users WHERE email = @email');
```

The query template and the value are sent **separately** to the database server. The server compiles the query template first, then substitutes the value as **data** — never as SQL syntax. No matter what the attacker puts in `email`, it is treated as a string to match, not as SQL to execute.

### In AzureShop

Every database operation in user-service and order-service uses parameterized queries via the `mssql` Node.js library. The `.input()` method declares the parameter name and type; `.query()` uses the `@paramName` placeholder. This is enforced by the library — there is no way to accidentally concatenate SQL from `.input()` parameters.

### Other Protections We Apply

- **Principle of least privilege** — the SQL user (`sqladmin`) has only the permissions it needs
- **Pydantic validation** (product-service) — incoming data is validated against a schema before it reaches any query
- **Connection pooling** — `mssql` connection pool is created once at startup, not per-request, preventing connection exhaustion attacks
