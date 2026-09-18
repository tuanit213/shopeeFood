# Server Order Truth

Phase 2 makes authenticated orders server-authoritative.

- The Flutter client submits menu item IDs, quantities, option labels, delivery details, and an idempotency key through the `createOrder` callable.
- The callable requires Firebase Auth, reads the restaurant and menu documents, rejects unavailable catalog records, and calculates pricing with `pricingVersion`.
- The order stores immutable item, restaurant, address, pricing, and delivery snapshots. A new order always starts as `placed`, `statusVersion: 1`, and `driverId: null`.
- `ORDER_PLACED` is written in the same transaction as the order and idempotency record. A repeated key returns the original order ID without creating a second order.
- Client writes to `/orders` remain closed in Firestore rules. The client reads only orders owned by its Firebase UID.
- There is no GPS, synthetic driver position, driver assignment, merchant UI, or route migration in this phase.

The legacy local `OrderState` path remains available for unauthenticated migration-only use. It is not mixed with server orders and is never authoritative for authenticated checkout.
