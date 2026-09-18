import { initializeApp } from "firebase-admin/app";
import { onCall } from "firebase-functions/v2/https";
import { createOrderHandler } from "./orders/create_order";

initializeApp();
export const createOrder = onCall({ region: "asia-southeast1" }, createOrderHandler);
