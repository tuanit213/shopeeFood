export const PRICING_VERSION = 1;

export type PriceLine = { price: number; quantity: number; optionsTotal: number };

export function calculatePricing(lines: PriceLine[], driverTip: number, requestedDiscount: number) {
  const subtotal = lines.reduce((sum, line) => sum + (line.price + line.optionsTotal) * line.quantity, 0);
  const deliveryFee = subtotal >= 80000 ? 0 : 15000;
  const serviceFee = 3000;
  const automaticDiscount = subtotal >= 60000 ? 12000 : 0;
  const discount = Math.min(subtotal + deliveryFee + serviceFee + driverTip, automaticDiscount + requestedDiscount);
  const total = subtotal + deliveryFee + serviceFee + driverTip - discount;
  return { subtotal, deliveryFee, serviceFee, driverTip, discount, total, pricingVersion: PRICING_VERSION };
}
