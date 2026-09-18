import { getFirestore, FieldValue, Timestamp } from "firebase-admin/firestore";
import { HttpsError, CallableRequest } from "firebase-functions/v2/https";
import { CreateOrderInput, validateCreateOrder } from "./order_validation";
import { calculatePricing } from "./pricing_policy";

export async function createOrderHandler(request: CallableRequest<unknown>) {
  if (!request.auth?.uid) throw new HttpsError("unauthenticated", "Authentication required");
  const input = validateCreateOrder(request.data) as CreateOrderInput;
  const db = getFirestore();
  const uid = request.auth.uid;
  const idemRef = db.doc(`users/${uid}/orderIdempotency/${input.idempotencyKey}`);
  const orderRef = db.collection("orders").doc();
  const now = Timestamp.now();

  return db.runTransaction(async (tx) => {
    const idem = await tx.get(idemRef);
    if (idem.exists) {
      const existingOrderId = idem.data()?.orderId;
      if (typeof existingOrderId !== "string") throw new HttpsError("internal", "Invalid idempotency record");
      return { orderId: existingOrderId, replayed: true };
    }
    const restaurantSnap = await tx.get(db.doc(`restaurants/${input.restaurantId}`));
    if (!restaurantSnap.exists) throw new HttpsError("failed-precondition", "Restaurant is unavailable");
    const restaurant = restaurantSnap.data()!;
    if (restaurant.status && restaurant.status !== "active") throw new HttpsError("failed-precondition", "Restaurant is unavailable");
    let branchSnap = await tx.get(db.doc(`restaurantBranches/${input.branchId}`));
    if (!branchSnap.exists) {
      const branches = await tx.get(
        db.collection("restaurantBranches").where("restaurantId", "==", input.restaurantId).limit(10),
      );
      const fallback = branches.docs.find((doc) => doc.data().deliveryEnabled === true && doc.data().status === "active");
      if (fallback) branchSnap = fallback;
    }
    if (!branchSnap.exists || branchSnap.data()?.restaurantId !== input.restaurantId || branchSnap.data()?.deliveryEnabled !== true || branchSnap.data()?.status !== "active") {
      throw new HttpsError("failed-precondition", "Delivery branch is unavailable");
    }

    const items = [];
    const lines = [];
    for (const requested of input.items) {
      const menuRef = db.doc(`restaurants/${input.restaurantId}/menuItems/${requested.menuItemId}`);
      const menuSnap = await tx.get(menuRef);
      if (!menuSnap.exists || menuSnap.data()?.available === false) throw new HttpsError("failed-precondition", "Menu item is unavailable");
      const menu = menuSnap.data()!;
      const allowedOptions = Array.isArray(menu.options) ? menu.options : [];
      const optionSnapshots = (requested.options ?? []).map((option) => {
        const resolved = allowedOptions.find((candidate: unknown) => {
          return candidate !== null && typeof candidate === "object" && String((candidate as Record<string, unknown>).name) === option.name;
        }) as Record<string, unknown> | undefined;
        if (!resolved) throw new HttpsError("failed-precondition", "Menu option is unavailable");
        const priceDelta = Number(resolved.priceDelta ?? 0);
        if (!Number.isFinite(priceDelta) || priceDelta < 0) throw new HttpsError("failed-precondition", "Menu option price is invalid");
        return { name: String(resolved.name), priceDelta };
      });
      const price = Number(menu.price);
      if (!Number.isFinite(price) || price < 0) throw new HttpsError("failed-precondition", "Menu price is invalid");
      const optionsTotal = optionSnapshots.reduce((sum, option) => sum + option.priceDelta, 0);
      items.push({ menuItemId: requested.menuItemId, nameSnapshot: String(menu.name ?? "Món ăn"), priceSnapshot: price, imageSnapshot: String(menu.imageUrl ?? ""), optionsSnapshot: optionSnapshots, quantity: requested.quantity, lineTotalSnapshot: (price + optionsTotal) * requested.quantity });
      lines.push({ price, quantity: requested.quantity, optionsTotal });
    }
    const pricing = calculatePricing(lines, input.driverTip ?? 0, 0);
    const order = {
      customerId: uid, restaurantId: input.restaurantId, branchId: branchSnap.id, driverId: null,
      status: "placed", statusVersion: 1, items,
      deliveryAddressSnapshot: { formattedAddress: input.deliveryAddress.formattedAddress, receiverName: input.deliveryAddress.receiverName, receiverPhone: input.deliveryAddress.receiverPhone, id: "checkout", label: "", source: "manual", verified: false, addressComponents: {}, location: { latitude: input.deliveryAddress.latitude ?? 0, longitude: input.deliveryAddress.longitude ?? 0 } },
      restaurantSnapshot: { id: restaurantSnap.id, ...restaurant }, pricing,
      delivery: { distanceMeters: null, estimatedDurationSeconds: null, pickupEta: null, deliveryEta: null },
      timeline: { createdAt: now, confirmedAt: null, driverAssignedAt: null, deliveredAt: null, cancelledAt: null },
      paymentMethod: input.paymentMethod, orderNote: input.orderNote, useCutlery: input.useCutlery,
      createdAt: now, updatedAt: now,
    };
    tx.create(orderRef, order);
    tx.create(orderRef.collection("events").doc("ORDER_PLACED"), { type: "ORDER_PLACED", actorType: "customer", actorId: uid, createdAt: now, statusVersion: 1 });
    tx.create(idemRef, { orderId: orderRef.id, createdAt: now });
    return { orderId: orderRef.id, replayed: false };
  });
}
