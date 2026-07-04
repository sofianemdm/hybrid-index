// Service worker COMBINÉ : notifications push (Firebase Cloud Messaging) + installabilité PWA.
// - Push : reçoit les messages en arrière-plan et affiche la notification système.
// - Install : handler fetch présent (critère d'installabilité) mais NON interceptant → aucune mise
//   en cache, donc aucun risque de servir une version périmée. Purge les anciens caches/SW.
// La config Firebase web (apiKey/appId/… ) est PUBLIQUE côté client (identifiants, pas des secrets).
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyBF50kfZ_0taNdhwkRCa5Qcz5ZhWTMG0Ig',
  authDomain: 'hybrid-index-ffe2c.firebaseapp.com',
  projectId: 'hybrid-index-ffe2c',
  storageBucket: 'hybrid-index-ffe2c.firebasestorage.app',
  messagingSenderId: '702021189861',
  appId: '1:702021189861:web:151fba59a8cee7574e940c',
});

const messaging = firebase.messaging();

// Message reçu alors que l'app N'EST PAS au premier plan → notification système.
messaging.onBackgroundMessage((payload) => {
  const n = (payload && payload.notification) || {};
  self.registration.showNotification(n.title || 'Athlete League', {
    body: n.body || '',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    tag: (payload && payload.data && payload.data.type) || 'athlete-league',
    data: (payload && payload.data) || {},
  });
});

// Tap sur la notification → focalise l'onglet existant ou ouvre l'app.
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((cs) => {
      for (const c of cs) {
        if ('focus' in c) return c.focus();
      }
      if (self.clients.openWindow) return self.clients.openWindow('/');
    }),
  );
});

// --- Installabilité PWA + anti-cache-périmé ---
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    try {
      const keys = await caches.keys();
      await Promise.all(keys.map((k) => caches.delete(k)));
    } catch (_) {/* best-effort */}
    await self.clients.claim();
  })());
});
// Handler fetch présent (critère d'install) mais on n'intercepte rien → toujours le réseau.
self.addEventListener('fetch', () => {});
