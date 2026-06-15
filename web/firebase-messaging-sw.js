/* global clients, firebase, importScripts, self */

importScripts(
  "https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js",
);
importScripts(
  "https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js",
);

firebase.initializeApp({
  apiKey: "AIzaSyDlGzhW9UWlzv4F_QxZZEfo_mxM6zozEUs",
  appId: "1:559786376992:web:d05b147a4e1f928341e145",
  messagingSenderId: "559786376992",
  projectId: "travelling-with-flutter",
  authDomain: "travelling-with-flutter.firebaseapp.com",
  storageBucket: "travelling-with-flutter.firebasestorage.app",
  measurementId: "G-VNZ68XB6WF",
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const data = payload.data || {};
  const notification = payload.notification || {};
  const title = notification.title || data.title || "Trip reminder";
  const options = {
    body: notification.body || data.body || "Open your trip itinerary.",
    icon: "icons/Icon-192.png",
    badge: "icons/Icon-192.png",
    tag: data.tag || data.tripId || "trip-reminder",
    data,
  };

  self.registration.showNotification(title, options);
});

self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  const targetUrl = new URL("/", self.location.origin).href;

  event.waitUntil(
    clients
      .matchAll({type: "window", includeUncontrolled: true})
      .then((clientList) => {
        for (const client of clientList) {
          if ("focus" in client) return client.focus();
        }
        if (clients.openWindow) return clients.openWindow(targetUrl);
        return undefined;
      }),
  );
});
