// ── Web Push handler ──────────────────────────────────────────────────────────
// Receives a push event from the server (via Webpush gem) and shows a
// browser notification. The payload must be JSON: { title, body, icon, badge, data }

self.addEventListener("push", async (event) => {
  if (!event.data) return;

  let payload;
  try {
    payload = event.data.json();
  } catch (_) {
    payload = { title: "New message", body: event.data.text() };
  }

  const title   = payload.title   || "Chat";
  const options = {
    body:    payload.body    || "",
    icon:    payload.icon    || "/icon.png",
    badge:   payload.badge   || "/icon.png",
    vibrate: [200, 100, 200],
    data:    payload.data    || { path: "/" },
    actions: [
      { action: "open",    title: "Open chat" },
      { action: "dismiss", title: "Dismiss" }
    ]
  };

  event.waitUntil(self.registration.showNotification(title, options));
});

// ── Notification click handler ────────────────────────────────────────────────
// Opens or focuses the chat window at the conversation URL when the user
// taps the notification.

self.addEventListener("notificationclick", (event) => {
  event.notification.close();

  if (event.action === "dismiss") return;

  const targetPath = event.notification.data?.path || "/";

  event.waitUntil(
    clients.matchAll({ type: "window", includeUncontrolled: true }).then((clientList) => {
      // Try to focus an already-open tab at the right URL
      for (const client of clientList) {
        const clientPath = new URL(client.url).pathname;
        if (clientPath === targetPath && "focus" in client) {
          return client.focus();
        }
      }
      // Otherwise open a new window
      if (clients.openWindow) {
        return clients.openWindow(targetPath);
      }
    })
  );
});

// ── Install / activate (basic cache-first shell) ──────────────────────────────
const CACHE_NAME = "chat-sw-v1";
const PRECACHE   = ["/", "/manifest.json", "/icon.png"];

self.addEventListener("install", (event) => {
  self.skipWaiting();
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.addAll(PRECACHE))
  );
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((k) => k !== CACHE_NAME).map((k) => caches.delete(k)))
    ).then(() => clients.claim())
  );
});
