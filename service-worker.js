const CACHE_PREFIX = 'aitm-course-pwa-';
const SHELL_CACHE = `${CACHE_PREFIX}shell-v1`;
const IMAGE_CACHE = `${CACHE_PREFIX}images-v1`;
const MAX_IMAGE_CACHE_BYTES = 24 * 1024 * 1024;
const APP_SHELL = [
  './',
  './index.html',
  './manifest.webmanifest',
  './images/AITM_logo_traced.svg',
  './images/HKUARTS_Logo white.svg',
  './images/HKUARTS_Logo2 horizontal white.svg',
  './images/pwa-icon-192.png',
  './images/pwa-icon-512.png',
  './images/pwa-maskable-512.png'
];

self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(SHELL_CACHE)
      .then(cache => cache.addAll(APP_SHELL))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys()
      .then(keys => Promise.all(keys
        .filter(key => key.startsWith(CACHE_PREFIX) && ![SHELL_CACHE, IMAGE_CACHE].includes(key))
        .map(key => caches.delete(key))))
      .then(() => self.clients.claim())
  );
});

async function cacheImage(request, response) {
  const responseSize = Number(response.headers.get('content-length'));
  if (!response.ok || !Number.isFinite(responseSize) || responseSize <= 0 || responseSize > MAX_IMAGE_CACHE_BYTES) return;

  const cache = await caches.open(IMAGE_CACHE);
  await cache.put(request, response);
  const entries = await Promise.all((await cache.keys()).map(async key => {
    const cached = await cache.match(key);
    return [key, Number(cached.headers.get('content-length')) || 0];
  }));
  let totalSize = entries.reduce((total, entry) => total + entry[1], 0);

  for (const [key, size] of entries) {
    if (totalSize <= MAX_IMAGE_CACHE_BYTES) break;
    await cache.delete(key);
    totalSize -= size;
  }
}

self.addEventListener('fetch', event => {
  const request = event.request;
  const requestUrl = new URL(request.url);
  if (request.method !== 'GET' || requestUrl.origin !== self.location.origin) return;

  if (request.mode === 'navigate') {
    event.respondWith((async () => {
      try {
        const response = await fetch(request);
        if (response.ok) {
          const cache = await caches.open(SHELL_CACHE);
          await cache.put(request, response.clone());
        }
        return response;
      } catch {
        return (await caches.match(request)) || caches.match(new URL('./index.html', self.registration.scope));
      }
    })());
    return;
  }

  if (requestUrl.pathname.includes('/images/')) {
    event.respondWith((async () => {
      const cached = await caches.match(request);
      if (cached) return cached;

      const response = await fetch(request);
      event.waitUntil(cacheImage(request, response.clone()));
      return response;
    })());
  }
});