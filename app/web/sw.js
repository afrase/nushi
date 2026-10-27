// Nushi's service worker (ADR 0054): the app's shell offline, and Web
// Push. It never caches what the app says to the daemon: that goes over a
// WebSocket, end to end encrypted, which a service worker doesn't see.
"use strict";

// make web fills these in: the build's files and a version that changes
// with them.
const VERSION = "nushi-dev";
const SHELL = ["./"];

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(VERSION).then((c) => c.addAll(SHELL)).then(() => self.skipWaiting()),
  );
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((k) => k !== VERSION).map((k) => caches.delete(k))))
      .then(() => self.clients.claim()),
  );
});

// The shell from the cache, the page from the network when it's there.
self.addEventListener("fetch", (event) => {
  const req = event.request;
  const url = new URL(req.url);
  if (req.method !== "GET" || url.origin !== self.location.origin) return;
  if (req.mode === "navigate") {
    event.respondWith(fetch(req).catch(() => caches.match("./", { cacheName: VERSION })));
    return;
  }
  event.respondWith(
    caches.match(req, { cacheName: VERSION }).then((hit) => hit || fetch(req)),
  );
});

// A chat's id, as the daemon makes them; anything else opens the list.
const chatId = (v) => (typeof v === "string" && /^[A-Za-z0-9_-]{1,64}$/.test(v) ? v : "");

// A push says only what happened ("Claude finished") and the chat to open.
self.addEventListener("push", (event) => {
  let data = {};
  try {
    data = event.data ? event.data.json() : {};
  } catch (e) {
    data = {};
  }
  const title = typeof data.title === "string" && data.title ? data.title.slice(0, 80) : "Nushi";
  const chat = chatId(data.chat);
  event.waitUntil(
    self.registration.showNotification(title, {
      tag: chat || "nushi",
      data: { chat },
      icon: "icons/Icon-192.png",
    }),
  );
});

// Tapping one opens the app at its chat: the open window if there is one.
self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  const chat = chatId(event.notification.data && event.notification.data.chat);
  event.waitUntil(
    self.clients.matchAll({ type: "window", includeUncontrolled: true }).then((wins) => {
      for (const w of wins) {
        if (new URL(w.url).origin === self.location.origin) {
          if (chat) w.postMessage({ chat });
          return w.focus();
        }
      }
      return self.clients.openWindow(chat ? "./#chat=" + encodeURIComponent(chat) : "./");
    }),
  );
});
