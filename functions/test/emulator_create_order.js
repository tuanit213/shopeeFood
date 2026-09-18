const assert = require('node:assert/strict');
const admin = require('firebase-admin');

const projectId = process.env.GCLOUD_PROJECT || 'shopeefood-6a82f';
admin.initializeApp({ projectId });
const db = admin.firestore();

async function json(url, body, headers = {}) {
  const response = await fetch(url, {
    method: 'POST',
    headers: { 'content-type': 'application/json', ...headers },
    body: JSON.stringify(body),
  });
  const payload = await response.json();
  assert.equal(response.ok, true, JSON.stringify(payload));
  return payload;
}

async function main() {
  await db.doc('restaurants/restaurant-1').set({ id: 'restaurant-1', name: 'Test Restaurant', status: 'active', description: '', logoUrl: '', coverUrl: '', categories: [], rating: 5, ratingCount: 1, verified: true, merchantIds: [], createdAt: new Date(), updatedAt: new Date() });
  await db.doc('restaurantBranches/branch-1').set({ restaurantId: 'restaurant-1', status: 'active', deliveryEnabled: true });
  await db.doc('restaurants/restaurant-1/menuItems/dish-1').set({ name: 'Test Dish', price: 40000, imageUrl: '', available: true, options: [{ name: 'Extra', priceDelta: 5000 }] });
  const auth = await json('http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-api-key', { email: 'order-test@example.com', password: 'password123', returnSecureToken: true });
  const input = { data: { idempotencyKey: 'emulator-test-1', restaurantId: 'restaurant-1', branchId: 'client-does-not-know-branch', items: [{ menuItemId: 'dish-1', quantity: 2, options: [{ name: 'Extra' }] }], deliveryAddress: { formattedAddress: '1 Test Street', receiverName: 'Test Customer', receiverPhone: '0900000000' }, driverTip: 0 } };
  const endpoint = 'http://127.0.0.1:5001/shopeefood-6a82f/asia-southeast1/createOrder';
  const first = await json(endpoint, input, { authorization: `Bearer ${auth.idToken}` });
  const second = await json(endpoint, input, { authorization: `Bearer ${auth.idToken}` });
  assert.equal(first.result.orderId, second.result.orderId);
  const order = await db.doc(`orders/${first.result.orderId}`).get();
  assert.equal(order.data().status, 'placed');
  assert.equal(order.data().driverId, null);
  assert.equal(order.data().branchId, 'branch-1');
  assert.equal(order.data().pricing.subtotal, 90000);
  assert.equal((await order.ref.collection('events').doc('ORDER_PLACED').get()).exists, true);
  console.log('emulator createOrder: idempotency, snapshots, pricing, event passed');
}

main().catch((error) => { console.error(error); process.exitCode = 1; });
