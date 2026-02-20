// app/views/pwa/service_worker.js.erb

const CACHE_NAME = "broadway-pwa-cache-v1";
const URLS_TO_CACHE = [
  "/",
  "/manifest.json",
  "/icon.png"
];

// 1. INSTALL: Save the essential files to the device
self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      console.log("Opened cache");
      return cache.addAll(URLS_TO_CACHE);
    })
  );
  // Force the waiting service worker to become the active service worker.
  self.skipWaiting();
});

// 2. ACTIVATE: Clean up old caches if we update the version number
self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames.map((name) => {
          if (name !== CACHE_NAME) {
            return caches.delete(name);
          }
        })
      );
    })
  );
  self.clients.claim();
});

// 3. FETCH: "Network First, fallback to Cache" Strategy
self.addEventListener("fetch", (event) => {
  // We only want to cache standard GET requests (ignore form submissions/PATCH)
  if (event.request.method !== "GET") return;

  event.respondWith(
    fetch(event.request)
      .then((response) => {
        // If the network request is successful, clone it and update the cache
        // so the offline version is always the most recent version!
        if (response && response.status === 200 && response.type === 'basic') {
          const responseToCache = response.clone();
          caches.open(CACHE_NAME).then((cache) => {
            cache.put(event.request, responseToCache);
          });
        }
        return response;
      })
      .catch(() => {
        // If the network fails (Offline!), return the cached version
        return caches.match(event.request);
      })
  );
});