// Service worker MINIMAL — rend l'app installable (PWA) sur Android/Chrome, SANS jamais mettre en
// cache : aucune requête n'est interceptée, donc AUCUN risque de servir une version périmée (c'est
// exactement ce qui nous avait piégés avec l'ancien SW offline-first). En prime, à l'activation il
// PURGE tout ancien cache/SW laissé par les visiteurs déjà venus.
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

// Handler `fetch` présent = critère d'installabilité rempli, MAIS on n'appelle jamais
// respondWith : le navigateur fait sa requête réseau normale. Jamais de contenu servi depuis un cache.
self.addEventListener('fetch', () => {});
