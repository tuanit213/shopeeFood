import { HttpsError } from "firebase-functions/v2/https";

export type CreateOrderInput = {
  idempotencyKey: string;
  restaurantId: string;
  branchId: string;
  items: Array<{ menuItemId: string; quantity: number; options?: Array<{ name: string }> }>;
  deliveryAddress: {
    formattedAddress: string;
    receiverName: string;
    receiverPhone: string;
    latitude?: number;
    longitude?: number;
  };
  paymentMethod?: string;
  driverTip?: number;
  orderNote?: string;
  useCutlery?: boolean;
};

const text = (value: unknown, field: string, max = 200): string => {
  if (typeof value !== "string" || value.trim().length === 0 || value.length > max) {
    throw new HttpsError("invalid-argument", `${field} is invalid`);
  }
  return value.trim();
};

export function validateCreateOrder(data: unknown): CreateOrderInput {
  if (!data || typeof data !== "object") throw new HttpsError("invalid-argument", "Invalid payload");
  const raw = data as Record<string, unknown>;
  const items = raw.items;
  if (!Array.isArray(items) || items.length === 0 || items.length > 50) {
    throw new HttpsError("invalid-argument", "At least one item is required");
  }
  const parsedItems = items.map((item) => {
    if (!item || typeof item !== "object") throw new HttpsError("invalid-argument", "Invalid item");
    const value = item as Record<string, unknown>;
    const quantity = value.quantity;
    if (typeof quantity !== "number" || !Number.isInteger(quantity) || quantity < 1 || quantity > 99) {
      throw new HttpsError("invalid-argument", "Invalid quantity");
    }
    const options = value.options;
    if (options !== undefined && (!Array.isArray(options) || options.length > 20)) {
      throw new HttpsError("invalid-argument", "Invalid options");
    }
    return {
      menuItemId: text(value.menuItemId, "menuItemId", 120),
      quantity,
      options: (options as Array<Record<string, unknown>> | undefined)?.map((option) => ({ name: text(option.name, "option", 80) })),
    };
  });
  const address = raw.deliveryAddress;
  if (!address || typeof address !== "object") throw new HttpsError("invalid-argument", "Address is required");
  const rawAddress = address as Record<string, unknown>;
  const driverTip = raw.driverTip ?? 0;
  if (typeof driverTip !== "number" || driverTip < 0 || driverTip > 1_000_000) throw new HttpsError("invalid-argument", "Invalid tip");
  const idempotencyKey = text(raw.idempotencyKey, "idempotencyKey", 100);
  if (!/^[A-Za-z0-9._:-]+$/.test(idempotencyKey)) {
    throw new HttpsError("invalid-argument", "Invalid idempotencyKey");
  }
  return {
    idempotencyKey,
    restaurantId: text(raw.restaurantId, "restaurantId", 120),
    branchId: text(raw.branchId, "branchId", 120),
    items: parsedItems,
    deliveryAddress: {
      formattedAddress: text(rawAddress.formattedAddress, "formattedAddress", 500),
      receiverName: text(rawAddress.receiverName, "receiverName", 120),
      receiverPhone: text(rawAddress.receiverPhone, "receiverPhone", 40),
      latitude: typeof rawAddress.latitude === "number" ? rawAddress.latitude : undefined,
      longitude: typeof rawAddress.longitude === "number" ? rawAddress.longitude : undefined,
    },
    paymentMethod: typeof raw.paymentMethod === "string" ? raw.paymentMethod.slice(0, 40) : "Tiền mặt",
    driverTip,
    orderNote: typeof raw.orderNote === "string" ? raw.orderNote.slice(0, 300) : "",
    useCutlery: raw.useCutlery === true,
  };
}
