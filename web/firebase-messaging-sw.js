importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js");

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

messaging.onBackgroundMessage((payload) => {
  console.log("[firebase-messaging-sw.js] Received background message ", payload);
  const notificationTitle = payload.notification?.title || "Tindahan ni Eca";
  const notificationOptions = {
    body: payload.notification?.body || "",
    icon: "/icons/Icon-192.png"
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});
