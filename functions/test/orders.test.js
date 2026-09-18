const assert = require('node:assert/strict');
const { calculatePricing } = require('../lib/orders/pricing_policy');
const { validateCreateOrder } = require('../lib/orders/order_validation');

const valid = {
  idempotencyKey: 'checkout-1',
  restaurantId: 'restaurant-1',
  branchId: 'branch-1',
  items: [{ menuItemId: 'dish-1', quantity: 2 }],
  deliveryAddress: {
    formattedAddress: '1 Test Street',
    receiverName: 'Customer',
    receiverPhone: '0900000000',
  },
};

assert.deepEqual(calculatePricing([{ price: 40000, quantity: 2, optionsTotal: 0 }], 0, 0), {
  subtotal: 80000,
  deliveryFee: 0,
  serviceFee: 3000,
  driverTip: 0,
  discount: 12000,
  total: 71000,
  pricingVersion: 1,
});
assert.equal(validateCreateOrder(valid).items[0].quantity, 2);
assert.throws(() => validateCreateOrder({ ...valid, items: [] }));
console.log('order tests: 3 passed');
