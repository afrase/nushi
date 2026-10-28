// Nushi's service worker (ADR 0054): the app's shell offline, and Web
// Push. It never caches what the app says to the daemon: that goes over a
// WebSocket, end to end encrypted, which a service worker doesn't see.
"use strict";

// make web fills these in: the build's files and a version that changes
// with them.
const VERSION = "nushi-dev";
const SHELL = ["./"];
// The engine's fallback fonts (Noto for CJK, emoji and other scripts) aren't
// in the shell: the engine asks for one when a character on screen needs it.
// Each is kept, once fetched, in a cache of its own named for the font list,
// so app updates keep it.
const FONTS = "nushi-fonts-dev";
const FONTS_PATH = new URL("assets/fonts/fallback/", self.location).pathname;
// The phone's frame for agents' pages: a navigation of its own (in an
// iframe), not the app's page.
const FRAME_PATH = new URL("frame.html", self.location).pathname;

// The whole shell, checked with the server (a CDN may have stretched an
// HTTP cache's hours; unchanged files cost a 304), before this
// version takes over. The first one takes over at once; a later one waits
// while a page runs the version before (whose files it would delete), until
// the page says "Reload" (the app offers it once this one is installed).
self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(VERSION)
      .then((c) => c.addAll(SHELL.map((u) => new Request(u, { cache: "no-cache" }))))
      .then(() => (self.registration.active ? undefined : self.skipWaiting())),
  );
});

self.addEventListener("message", (event) => {
  if (event.data === "skipWaiting") self.skipWaiting();
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((k) => k !== VERSION && k !== FONTS).map((k) => caches.delete(k))))
      .then(() => self.clients.claim()),
  );
});

// Everything from the cache, the page too: a launch costs no round trip,
// and the page and its files are always one version. A newer version
// installs in the background and waits for the app's Reload.
self.addEventListener("fetch", (event) => {
  const req = event.request;
  const url = new URL(req.url);
  if (req.method !== "GET" || url.origin !== self.location.origin) return;
  if (url.pathname.startsWith(FONTS_PATH) && url.pathname.endsWith(".woff2")) {
    event.respondWith(fallbackFont(req));
    return;
  }
  if (req.mode === "navigate" && url.pathname !== FRAME_PATH) {
    event.respondWith(
      caches.match("./", { cacheName: VERSION }).then((hit) => hit || fetch(req)),
    );
    return;
  }
  event.respondWith(
    caches.match(req, { cacheName: VERSION }).then((hit) => hit || fetch(req)),
  );
});

// A fallback font from its cache, else from the relay, kept if it came
// whole from this origin.
async function fallbackFont(req) {
  const cache = await caches.open(FONTS);
  const hit = await cache.match(req);
  if (hit) return hit;
  const res = await fetch(req);
  if (res.ok && res.status === 200 && res.type === "basic") {
    await cache.put(req, res.clone());
  }
  return res;
}

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
  const kind = ["finished", "question", "permission", "test"].includes(data.kind) ? data.kind : "";
  event.waitUntil(
    self.registration.showNotification(title, {
      // One per chat and kind: a question doesn't silently replace a turn's end.
      tag: chat ? chat + ":" + kind : "nushi",
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
