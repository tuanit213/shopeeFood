const fs = require('node:fs');
const path = require('node:path');
const { after, before, beforeEach, test } = require('node:test');
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');
const { doc, getDoc, setDoc, updateDoc, deleteDoc } = require('firebase/firestore');

let env;

before(async () => {
  const rules = fs.readFileSync(path.resolve(__dirname, '../../firestore.rules'), 'utf8');
  env = await initializeTestEnvironment({
    projectId: 'shopeefood-phase1-test',
    firestore: { rules, host: '127.0.0.1', port: 8081 },
  });
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'users/user-a'), {
      uid: 'user-a', role: 'customer', status: 'active', displayName: 'A',
    });
    await setDoc(doc(db, 'users/user-b'), {
      uid: 'user-b', role: 'customer', status: 'active', displayName: 'B',
    });
    await setDoc(doc(db, 'restaurants/r-1'), { name: 'Restaurant' });
    await setDoc(doc(db, 'restaurantBranches/b-1/menuItems/m-1'), { name: 'Meal' });
    await setDoc(doc(db, 'orders/o-1'), {
      customerId: 'user-a', driverId: null, status: 'placed',
      pricing: { total: 100000 },
    });
  });
});

after(async () => env?.cleanup());

test('private profiles require ownership', async () => {
  const anonymous = env.unauthenticatedContext().firestore();
  const userA = env.authenticatedContext('user-a').firestore();
  await assertFails(getDoc(doc(anonymous, 'users/user-a')));
  await assertSucceeds(getDoc(doc(userA, 'users/user-a')));
  await assertFails(getDoc(doc(userA, 'users/user-b')));
});

test('users CRUD only their own addresses', async () => {
  const userA = env.authenticatedContext('user-a').firestore();
  const own = doc(userA, 'users/user-a/addresses/address-1');
  const other = doc(userA, 'users/user-b/addresses/address-1');
  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'users/user-b/addresses/address-1'), {
      label: 'Other',
    });
  });
  await assertSucceeds(setDoc(own, { label: 'Home' }));
  await assertSucceeds(getDoc(own));
  await assertSucceeds(updateDoc(own, { label: 'Work' }));
  await assertSucceeds(deleteDoc(own));
  await assertFails(setDoc(other, { label: 'Other' }));
  await assertFails(getDoc(other));
  await assertFails(updateDoc(other, { label: 'No' }));
  await assertFails(deleteDoc(other));
});

test('catalog is authenticated read-only', async () => {
  const userA = env.authenticatedContext('user-a').firestore();
  await assertSucceeds(getDoc(doc(userA, 'restaurants/r-1')));
  await assertSucceeds(getDoc(doc(userA, 'restaurantBranches/b-1/menuItems/m-1')));
  await assertFails(setDoc(doc(userA, 'restaurants/r-2'), { name: 'No' }));
  await assertFails(updateDoc(doc(userA, 'restaurants/r-1'), { name: 'No' }));
});

test('customers cannot mutate orders or escalate role', async () => {
  const anonymous = env.unauthenticatedContext().firestore();
  const userA = env.authenticatedContext('user-a').firestore();
  const userB = env.authenticatedContext('user-b').firestore();
  await assertFails(getDoc(doc(anonymous, 'orders/o-1')));
  await assertSucceeds(getDoc(doc(userA, 'orders/o-1')));
  await assertFails(getDoc(doc(userB, 'orders/o-1')));
  await assertFails(setDoc(doc(userA, 'orders/o-2'), {
    customerId: 'user-a', status: 'placed', driverId: null,
    pricing: { total: 100000 },
  }));
  await assertFails(updateDoc(doc(userA, 'orders/o-1'), {
    driverId: 'driver-1', status: 'delivered', pricing: { total: 1 },
  }));
  await assertFails(updateDoc(doc(userA, 'users/user-a'), { role: 'admin' }));
});
