# Software Requirements Specification - ShopeeFood Delivery

Version: 1.0  
Prepared for: project review on 2026-10-13  
Product scope: customer ordering app, trusted order backend, and delivery integration foundation.

## 1. Purpose

The system lets a customer authenticate, browse a restaurant catalog, configure a cart, choose a delivery address, create an order through a trusted server, and track its delivery state. Firebase Authentication identifies users, Firestore stores application data, and Cloud Functions owns sensitive order creation logic.

## 2. Actors

| Actor | Responsibility |
| --- | --- |
| Customer | Manage profile and addresses, browse catalog, place and track orders. |
| Driver | Receive an assignment, update pickup/delivery progress, publish location, and settle COD. |
| Administrator | Maintain catalog data, monitor orders, and support release operations. |
| Firebase backend | Authenticate requests, enforce rules, calculate trusted totals, and persist immutable order snapshots. |

## 3. Functional requirements

| ID | Requirement | Current evidence |
| --- | --- | --- |
| FR-01 | A customer can register, sign in, sign out, and restore a valid session. | Flutter auth repositories and session tests. |
| FR-02 | A customer can browse restaurants, menu sections, menu items, and option groups. | Catalog domain/repositories and catalog seed schema. |
| FR-03 | The cart supports quantity changes, options, persistence, and one-restaurant consistency. | Checkout/order state implementation and tests. |
| FR-04 | A customer can create and edit owner-scoped delivery addresses. | Address V2 model/repository and Firestore rules. |
| FR-05 | Order totals are calculated from server-owned catalog data, not client prices. | Callable `createOrder`, pricing policy, and emulator integration test. |
| FR-06 | Repeated order submissions with the same idempotency key do not create duplicate orders. | `createOrder` idempotency record and emulator test. |
| FR-07 | An order stores immutable customer, restaurant, item, address, and price snapshots. | `OrderV2` contract and callable transaction. |
| FR-08 | A customer can view order status and delivery progress. | Order tracking UI; real-time server integration remains planned. |
| FR-09 | A driver can accept, pick up, prove delivery, complete an order, and update COD. | Separate driver MVP repository; production backend integration is pending. |
| FR-10 | Administrators can seed versioned catalog data into an isolated staging project. | Guarded seed tool exists; real approved dataset and staging project are pending. |

## 4. Non-functional requirements

| ID | Requirement |
| --- | --- |
| NFR-01 Security | Authentication is required for private data. Direct client writes to server-owned orders are denied. Users can access only their own profile, address, and order data. |
| NFR-02 Reliability | Order creation is transactional and idempotent. The UI has controlled fallback data for classroom demonstration. |
| NFR-03 Performance | Catalog reads use queryable Firestore projections; location uploads and route updates must be throttled. |
| NFR-04 Maintainability | Domain models and repositories isolate Firestore collection paths and compatibility adapters. |
| NFR-05 Testability | Flutter unit tests, Functions unit tests, Firestore rules tests, and emulator integration tests are required before release. |
| NFR-06 Deployability | Flutter Web can be served as static files on a VPS. Firebase Functions, rules, and indexes are deployed through Firebase, not copied to Nginx. |

## 5. Data and trust boundaries

- Firebase Auth is the identity source of truth.
- Firestore catalog documents are authenticated read-only data for clients.
- `createOrder` is the only trusted order-creation path.
- The server resolves prices and catalog availability and writes snapshots in a transaction.
- Demo/offline data is presentation fallback and must not be described as production data.
- Secrets, API keys, service-account files, and environment files are excluded from Git.

## 6. Acceptance criteria for the current milestone

1. `flutter analyze` exits with code 0.
2. All Flutter tests pass.
3. Functions TypeScript build and unit tests pass.
4. Auth + Firestore + Functions emulator integration passes for `createOrder`.
5. Firestore rules keep client order writes closed.
6. GitHub contains the reviewed branch/commit used for the demonstration.
7. Jira status and assignees match actual implementation evidence.
8. A VPS URL serves the Flutter Web build over HTTP/HTTPS, while Firebase deployment status is reported separately.

## 7. Known gaps

- No owner-approved real catalog records are present in the staging manifest.
- No isolated Firebase staging project has been selected and deployed.
- Driver assignment, real-time driver GPS, notification delivery, and production COD settlement are incomplete.
- The customer Flutter project and driver Flutter project are separate repositories and are not yet integrated through one production backend.
- VPS credentials/domain are not available in the repository; remote deployment cannot be verified locally.

## 8. Release decision

The system is ready for a local/emulator technical demonstration. It is not ready to be presented as a production deployment until the staging catalog, Firebase deployment, VPS URL, and end-to-end smoke test are completed.
