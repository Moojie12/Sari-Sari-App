importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js");

// Initialize Firebase in Service Worker
firebase.initializeApp({
  apiKey: "AIzaSyD-xEjxWySz4ZV4Natb_8fjHSm8l3Sh5_w",
  appId: "1:709594394959:web:09b1459f0fa9508b7c153a",
  messagingSenderId: "709594394959",
  projectId: "tindahan-ni-eca-app",
  authDomain: "tindahan-ni-eca-app.firebaseapp.com",
  storageBucket: "tindahan-ni-eca-app.firebasestorage.app",
  databaseURL: "https://tindahan-ni-eca-app-default-rtdb.firebaseio.com"
});

const messaging = firebase.messaging();

// Handle Background Push Messages when browser tab is minimized, hidden, or closed
messaging.onBackgroundMessage((payload) => {
  console.log("[firebase-messaging-sw.js] Received background message:", payload);

  const data = payload.data || {};
  const notification = payload.notification || {};

  const notificationTitle = notification.title || data.title || "Tindahan ni Eca Alert";
  const notificationBody = notification.body || data.body || data.message || "You have a new update.";
  const clickAction = data.click_action || data.url || "/";
  const notificationTag = data.tag || data.orderId || data.productId || ("tindahan-" + Date.now());

  // Interactive actions based on notification type
  const actions = [];
  if (data.type === "new_order" || data.orderId) {
    actions.push({ action: "view_order", title: "View Order" });
  } else if (data.type === "low_stock" || data.productId) {
    actions.push({ action: "view_inventory", title: "View Stock" });
  }
  actions.push({ action: "dismiss", title: "Dismiss" });

  const notificationOptions = {
    body: notificationBody,
    icon: notification.icon || "/icons/Icon-192.png",
    badge: "/favicon.png",
    tag: notificationTag,
    renotify: true,
    requireInteraction: true,
    vibrate: [200, 100, 200, 100, 200],
    data: {
      ...data,
      click_action: clickAction,
      receivedAt: Date.now()
    },
    actions: actions
  };

  return self.registration.showNotification(notificationTitle, notificationOptions);
});

// Handle interactive notification click events
self.addEventListener("notificationclick", (event) => {
  event.notification.close();

  if (event.action === "dismiss") {
    return;
  }

  const notificationData = event.notification.data || {};
  const targetUrl = notificationData.click_action || notificationData.url || "/";

  // Focus existing window or open a new one
  event.waitUntil(
    clients.matchAll({ type: "window", includeUncontrolled: true }).then((windowClients) => {
      // Check if an existing app tab is already open
      for (let i = 0; i < windowClients.length; i++) {
        const client = windowClients[i];
        if (client.url && "focus" in client) {
          // Notify the open client
          client.postMessage({
            type: "FCM_NOTIFICATION_CLICK",
            data: notificationData,
            action: event.action
          });
          return client.focus();
        }
      }

      // If no open client exists, open a new window
      if (clients.openWindow) {
        return clients.openWindow(targetUrl);
      }
    })
  );
});

// Immediately activate new service worker versions
self.addEventListener("install", () => {
  self.skipWaiting();
});

self.addEventListener("activate", (event) => {
  event.waitUntil(clients.claim());
});
