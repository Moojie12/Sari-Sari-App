const functions = require("firebase-functions");
const admin = require("firebase-admin");

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.database();
const messaging = admin.messaging();

/**
 * Helper to fetch all FCM device tokens for users matching specific roles.
 * Supports both users/{uid}/fcmToken and users/{uid}/fcmTokens/{tokenHash} maps.
 *
 * @param {string[]} targetRoles - e.g. ['admin', 'owner', 'employee']
 * @returns {Promise<{ tokens: string[], userTokensMap: Map<string, string[]> }>}
 */
async function getDeviceTokensForRoles(targetRoles) {
  const tokens = new Set();
  const userTokensMap = new Map();

  try {
    const snapshot = await db.ref("users").once("value");
    if (!snapshot.exists()) return { tokens: [], userTokensMap };

    const usersData = snapshot.val();
    for (const [uid, user] of Object.entries(usersData)) {
      if (!user || typeof user !== "object") continue;

      const userRole = (user.role || "customer").toLowerCase();
      const isRoleMatch = targetRoles.some((r) => r.toLowerCase() === userRole);
      if (!isRoleMatch) continue;

      const userTokenList = [];

      // 1. Check primary fcmToken string
      if (user.fcmToken && typeof user.fcmToken === "string" && user.fcmToken.trim().length > 10) {
        tokens.add(user.fcmToken.trim());
        userTokenList.push(user.fcmToken.trim());
      }

      // 2. Check fcmTokens multi-device map
      if (user.fcmTokens && typeof user.fcmTokens === "object") {
        for (const [key, tokenEntry] of Object.entries(user.fcmTokens)) {
          if (tokenEntry && typeof tokenEntry === "object" && tokenEntry.token) {
            tokens.add(tokenEntry.token.trim());
            userTokenList.push(tokenEntry.token.trim());
          } else if (typeof tokenEntry === "string" && tokenEntry.trim().length > 10) {
            tokens.add(tokenEntry.trim());
            userTokenList.push(tokenEntry.trim());
          }
        }
      }

      if (userTokenList.length > 0) {
        userTokensMap.set(uid, userTokenList);
      }
    }
  } catch (error) {
    console.error("[getDeviceTokensForRoles] Error retrieving tokens:", error);
  }

  return { tokens: Array.from(tokens), userTokensMap };
}

/**
 * Remove invalid/unregistered FCM registration tokens from RTDB users node.
 *
 * @param {string[]} failedTokens
 */
async function pruneInvalidTokens(failedTokens) {
  if (!failedTokens || failedTokens.length === 0) return;

  try {
    const snapshot = await db.ref("users").once("value");
    if (!snapshot.exists()) return;

    const usersData = snapshot.val();
    const failedSet = new Set(failedTokens);

    for (const [uid, user] of Object.entries(usersData)) {
      if (!user || typeof user !== "object") continue;

      const updates = {};
      if (user.fcmToken && failedSet.has(user.fcmToken)) {
        updates[`users/${uid}/fcmToken`] = null;
      }

      if (user.fcmTokens && typeof user.fcmTokens === "object") {
        for (const [key, tokenEntry] of Object.entries(user.fcmTokens)) {
          const rawToken = typeof tokenEntry === "object" ? tokenEntry.token : tokenEntry;
          if (rawToken && failedSet.has(rawToken)) {
            updates[`users/${uid}/fcmTokens/${key}`] = null;
          }
        }
      }

      if (Object.keys(updates).length > 0) {
        await db.ref().update(updates);
        console.log(`[pruneInvalidTokens] Pruned ${Object.keys(updates).length} stale token(s) for user ${uid}`);
      }
    }
  } catch (err) {
    console.warn("[pruneInvalidTokens] Notice pruning tokens:", err);
  }
}

/**
 * Send Multicast FCM notification safely and clean up stale tokens.
 */
async function sendPushMulticast({ tokens, notification, data }) {
  if (!tokens || tokens.length === 0) {
    console.log("[sendPushMulticast] No target device tokens found. Skipping FCM delivery.");
    return { successCount: 0, failureCount: 0 };
  }

  const payload = {
    tokens: tokens,
    notification: {
      title: notification.title,
      body: notification.body,
    },
    data: Object.fromEntries(
      Object.entries(data || {}).map(([k, v]) => [k, String(v ?? "")])
    ),
    android: {
      priority: "high",
      notification: {
        channelId: "orders_channel",
        sound: "default",
        priority: "max",
        defaultVibrateTimings: true,
        visibility: "public",
        clickAction: "FLUTTER_NOTIFICATION_CLICK",
      },
    },
    webpush: {
      headers: {
        Urgency: "high",
      },
      notification: {
        icon: "/icons/Icon-192.png",
        badge: "/favicon.png",
        requireInteraction: true,
        tag: data?.orderId || data?.productId || `fcm-alert-${Date.now()}`,
      },
    },
  };

  try {
    const response = await messaging.sendEachForMulticast(payload);
    console.log(`[sendPushMulticast] Sent successfully to ${response.successCount}/${tokens.length} devices.`);

    const tokensToPrune = [];
    response.responses.forEach((resp, idx) => {
      if (!resp.success && resp.error) {
        const code = resp.error.code;
        if (
          code === "messaging/invalid-registration-token" ||
          code === "messaging/registration-token-not-registered"
        ) {
          tokensToPrune.push(tokens[idx]);
        }
      }
    });

    if (tokensToPrune.length > 0) {
      await pruneInvalidTokens(tokensToPrune);
    }

    return response;
  } catch (error) {
    console.error("[sendPushMulticast] Error delivering multicast notification:", error);
    return { successCount: 0, failureCount: tokens.length };
  }
}

// =============================================================================
// TRIGGER 1: NEW ORDER PLACEMENT -> Notify Owner & Employees
// Path: /orders/{orderId}
// =============================================================================
exports.onNewOrder = functions.database
  .ref("/orders/{orderId}")
  .onCreate(async (snapshot, context) => {
    const orderId = context.params.orderId;
    const orderData = snapshot.val();
    if (!orderData) return null;

    console.log(`[onNewOrder] Processing newly placed order: #${orderId}`);

    const customerName = orderData.customerName || "A customer";
    const totalAmount = Number(orderData.totalAmount || orderData.totalPrice || 0).toFixed(2);
    const orderType = orderData.orderType === "delivery" ? "Delivery" : "Pickup";
    const itemCount = Array.isArray(orderData.items)
      ? orderData.items.reduce((acc, item) => acc + (Number(item.quantity) || 1), 0)
      : (orderData.itemsCount || 1);

    const displayId = orderData.displayOrderId || (orderId.length > 8 ? orderId.slice(-6).toUpperCase() : orderId);
    const notifId = `notif_order_${orderId}_${Date.now()}`;

    // 1. Write store notification to RTDB /notifications/store/{notifId}
    // This allows active Flutter screens and streams to update in real-time
    try {
      await db.ref(`notifications/store/${notifId}`).set({
        id: notifId,
        type: "newOrder",
        title: "New Order Received!",
        message: `${customerName} placed order #${displayId} (${itemCount} items) for ₱${totalAmount} [${orderType}]`,
        orderId: orderId,
        timestamp: new Date().toISOString(),
        isRead: false,
      });
      console.log(`[onNewOrder] Written store notification record #${notifId} to RTDB`);
    } catch (dbErr) {
      console.error("[onNewOrder] Failed writing store notification record:", dbErr);
    }

    // 2. Fetch device tokens for Owner and Employees
    const { tokens } = await getDeviceTokensForRoles(["owner", "employee", "admin"]);
    console.log(`[onNewOrder] Discovered ${tokens.length} staff device token(s) for order notification`);

    // 3. Send background push notification via FCM
    return sendPushMulticast({
      tokens: tokens,
      notification: {
        title: "📦 New Order Received!",
        body: `Order #${displayId} from ${customerName}: ₱${totalAmount} (${itemCount} items)`,
      },
      data: {
        id: notifId,
        type: "new_order",
        orderId: orderId,
        role: "store",
        click_action: "/orders",
        title: "📦 New Order Received!",
        message: `Order #${displayId} from ${customerName}: ₱${totalAmount}`,
      },
    });
  });

// =============================================================================
// TRIGGER 2: INVENTORY STOCK DROP -> Low Stock Alert for Admin & Owner
// Path: /inventory/{productId}
// =============================================================================
exports.onInventoryStockUpdate = functions.database
  .ref("/inventory/{productId}")
  .onWrite(async (change, context) => {
    const productId = context.params.productId;
    const afterData = change.after.val();
    const beforeData = change.before.val() || {};

    if (!afterData) {
      console.log(`[onInventoryStockUpdate] Product ${productId} deleted from inventory`);
      return null;
    }

    const currentStock = Number(afterData.stock ?? afterData.totalStock ?? afterData.quantity ?? 0);
    const prevStock = Number(beforeData.stock ?? beforeData.totalStock ?? beforeData.quantity ?? 999999);
    const threshold = Number(afterData.minStock ?? afterData.lowStockThreshold ?? 5);
    const productName = afterData.name || afterData.productName || `Item #${productId}`;

    // Only fire trigger when stock transitions across the threshold downwards
    const isNowLowStock = currentStock <= threshold && prevStock > threshold;
    const isNowOutOfStock = currentStock <= 0 && prevStock > 0;

    if (!isNowLowStock && !isNowOutOfStock) {
      return null;
    }

    console.log(`[onInventoryStockUpdate] Low stock triggered for ${productName} (Current: ${currentStock}, Threshold: ${threshold})`);

    const notifId = `notif_lowstock_${productId}_${Date.now()}`;
    const alertTitle = isNowOutOfStock
      ? `🚨 Out of Stock: ${productName}`
      : `⚠️ Low Stock Alert: ${productName}`;
    const alertMessage = isNowOutOfStock
      ? `${productName} is completely OUT OF STOCK! Please restock immediately.`
      : `${productName} has dropped to ${currentStock} unit${currentStock === 1 ? "" : "s"} (Min threshold: ${threshold}). Please reorder soon.`;

    // 1. Write store notification record
    try {
      await db.ref(`notifications/store/${notifId}`).set({
        id: notifId,
        type: isNowOutOfStock ? "outOfStock" : "lowStock",
        title: alertTitle,
        message: alertMessage,
        productId: productId,
        productName: productName,
        timestamp: new Date().toISOString(),
        isRead: false,
      });
    } catch (err) {
      console.error("[onInventoryStockUpdate] Error saving store notification:", err);
    }

    // 2. Fetch device tokens for Admin & Owner
    const { tokens } = await getDeviceTokensForRoles(["admin", "owner"]);
    console.log(`[onInventoryStockUpdate] Discovered ${tokens.length} admin/owner device token(s)`);

    // 3. Send background push notification via FCM
    return sendPushMulticast({
      tokens: tokens,
      notification: {
        title: alertTitle,
        body: alertMessage,
      },
      data: {
        id: notifId,
        type: isNowOutOfStock ? "out_of_stock" : "low_stock",
        productId: productId,
        role: "admin",
        click_action: "/admin",
        title: alertTitle,
        message: alertMessage,
      },
    });
  });

// =============================================================================
// TRIGGER 3: PRODUCTS STOCK DROP (Alternate products node)
// Path: /products/{productId}
// =============================================================================
exports.onProductStockUpdate = functions.database
  .ref("/products/{productId}")
  .onWrite(async (change, context) => {
    const productId = context.params.productId;
    const afterData = change.after.val();
    const beforeData = change.before.val() || {};

    if (!afterData) return null;

    const currentStock = Number(afterData.stock ?? afterData.totalStock ?? afterData.quantity ?? 0);
    const prevStock = Number(beforeData.stock ?? beforeData.totalStock ?? beforeData.quantity ?? 999999);
    const threshold = Number(afterData.minStock ?? afterData.lowStockThreshold ?? 5);
    const productName = afterData.name || afterData.productName || `Item #${productId}`;

    const isNowLowStock = currentStock <= threshold && prevStock > threshold;
    const isNowOutOfStock = currentStock <= 0 && prevStock > 0;

    if (!isNowLowStock && !isNowOutOfStock) return null;

    const notifId = `notif_lowstock_${productId}_${Date.now()}`;
    const alertTitle = isNowOutOfStock
      ? `🚨 Out of Stock: ${productName}`
      : `⚠️ Low Stock Alert: ${productName}`;
    const alertMessage = isNowOutOfStock
      ? `${productName} is OUT OF STOCK! Please restock immediately.`
      : `${productName} has dropped to ${currentStock} units (Threshold: ${threshold}).`;

    try {
      await db.ref(`notifications/store/${notifId}`).set({
        id: notifId,
        type: isNowOutOfStock ? "outOfStock" : "lowStock",
        title: alertTitle,
        message: alertMessage,
        productId: productId,
        productName: productName,
        timestamp: new Date().toISOString(),
        isRead: false,
      });
    } catch (_) {}

    const { tokens } = await getDeviceTokensForRoles(["admin", "owner"]);
    return sendPushMulticast({
      tokens: tokens,
      notification: {
        title: alertTitle,
        body: alertMessage,
      },
      data: {
        id: notifId,
        type: isNowOutOfStock ? "out_of_stock" : "low_stock",
        productId: productId,
        role: "admin",
        click_action: "/admin",
        title: alertTitle,
        message: alertMessage,
      },
    });
  });

// =============================================================================
// HTTPS FUNCTION: Manual / Test Push Trigger
// =============================================================================
exports.sendTestNotification = functions.https.onRequest(async (req, res) => {
  const role = req.query.role || "all";
  const title = req.query.title || "🔔 Test Notification";
  const body = req.query.body || "This is a test notification from Tindahan ni Eca Cloud Functions.";

  let targetRoles = ["admin", "owner", "employee"];
  if (role === "admin") targetRoles = ["admin"];
  if (role === "owner") targetRoles = ["owner"];
  if (role === "employee") targetRoles = ["employee"];

  const { tokens } = await getDeviceTokensForRoles(targetRoles);

  const result = await sendPushMulticast({
    tokens: tokens,
    notification: { title, body },
    data: {
      type: "system_test",
      role: role,
      click_action: "/admin",
      title: title,
      message: body,
    },
  });

  return res.json({
    status: "success",
    targetRoles: targetRoles,
    recipientTokensCount: tokens.length,
    fcmResult: result,
  });
});
