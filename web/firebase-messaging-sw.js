/*
 * TRYP browser push service worker.
 * Replace the FIREBASE_WEB_* placeholders with the Firebase Web app config
 * before deploying. These values are public Firebase configuration values;
 * the Web Push VAPID key is configured in the Flutter .env file.
 */
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'FIREBASE_WEB_API_KEY',
  authDomain: 'FIREBASE_WEB_AUTH_DOMAIN',
  projectId: 'FIREBASE_WEB_PROJECT_ID',
  storageBucket: 'FIREBASE_WEB_STORAGE_BUCKET',
  messagingSenderId: 'FIREBASE_WEB_MESSAGING_SENDER_ID',
  appId: 'FIREBASE_WEB_APP_ID',
  measurementId: 'FIREBASE_WEB_MEASUREMENT_ID'
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const title = payload.notification?.title || 'TRYP';
  const options = {
    body: payload.notification?.body || 'You have a new ride update.',
    icon: '/icons/Icon-192.png',
    data: payload.data || {}
  };

  self.registration.showNotification(title, options);
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const route = event.notification.data?.route || '/notifications';
  const targetUrl = new URL(route, self.location.origin).href;

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      for (const client of clientList) {
        if ('focus' in client) {
          client.navigate(targetUrl);
          return client.focus();
        }
      }
      if (clients.openWindow) return clients.openWindow(targetUrl);
      return undefined;
    })
  );
});
