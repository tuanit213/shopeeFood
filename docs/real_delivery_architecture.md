# Real delivery architecture (Phase 1)

## Collections and ownership

* `users/{uid}` is owned by that authenticated user; role is customer by
  default and cannot be escalated from the client.
* `users/{uid}/addresses/{addressId}` stores owner-scoped `DeliveryAddressV2`.
* `restaurants/{restaurantId}` and `restaurantBranches/{branchId}` are
  authenticated, read-only catalog projections. Branch children are
  `menuSections`, `menuItems`, and `optionGroups`.
* `orders/{orderId}` and `orders/{orderId}/events/{eventId}` are server-owned
  in Phase 1. Customers may read only orders whose `customerId` is their UID.
* `drivers/{driverId}` and `ratings/{ratingId}` remain closed until trusted
  backend claims/workflows exist.

## Source of truth and cache

Firebase Auth owns identity. Firestore owns the new profile and catalog
contracts. SharedPreferences remains a local compatibility cache for the
legacy address/cart/order simulation; it is not authoritative delivery state.
Repository interfaces keep collection paths out of future widgets.

## Snapshots and lifecycle

`OrderV2` stores immutable item, address, restaurant, pricing, and delivery
snapshots so later catalog edits do not rewrite order history. Its status is an
explicit delivery state machine (`placed` through `delivered` or `cancelled`),
with `statusVersion` for optimistic/server transitions. Rating is intentionally
not a status. Nullable driver/ETA/timeline fields represent information that is
not available before trusted assignment or the corresponding event.

## Phase boundary

No GPS publisher, route API, payment, driver assignment, merchant UI, seed
script, or legacy fallback deletion is included here. Phase 2 can implement
server order creation/transitions and claims without changing these contracts.
