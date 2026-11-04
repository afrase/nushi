// Nushi's service worker (ADR 0054): the app's shell offline, and Web
// Push. It never caches what the app says to the daemon: that goes over a
// WebSocket, end to end encrypted, which a service worker doesn't see.
"use strict";

// make web fills these in: the build's files, each one's SHA-256 (hex; "./"
// is index.html), and a version that changes with them.
const VERSION = "nushi-dev";
const SHELL = ["./"];
const SUMS = {};
// The engine's fallback fonts (Noto for CJK, emoji and other scripts) aren't
// in the shell: the engine asks for one when a character on screen needs it.
// Each is kept, once fetched, in a cache of its own named for the font list,
// so app updates keep it. FONT_SUMS names the shell's file of their SHA-256s
// by name (fonts.lock's), or is "" when the build has none.
const FONTS = "nushi-fonts-dev";
const FONT_SUMS = "";
const FONTS_PATH = new URL("assets/fonts/fallback/", self.location).pathname;
// The phone's frame for agents' pages: a navigation of its own (in an
// iframe), not the app's page.
const FRAME_PATH = new URL("frame.html", self.location).pathname;

// Every cached answer is checked against the sum this worker came with,
// each time it's served: script that once ran on the app's origin can
// write the caches, and one altered answer from the server could have been
// kept; neither may outlive the server being put right, so what doesn't
// match is dropped and fetched again, and only what matches is kept.
const sums = new Map(Object.entries(SUMS).map(([k, v]) => [new URL(k, self.location).href, v]));
const page = new URL("./", self.location).href;

// The whole shell, checked with the server (a CDN may have stretched an
// HTTP cache's hours; unchanged files cost a 304) and against its sums,
// before this version takes over: one file that doesn't match fails the
// install, which the browser tries again later. The first one takes over
// at once; a later one waits while a page runs the version before (whose
// files it would delete), until the page says "Reload" (the app offers it
// once this one is installed).
self.addEventListener("install", (event) => {
  // A build make web didn't finish (no sums) keeps nothing.
  const shell = sums.size ? SHELL : [];
  event.waitUntil(
    caches.open(VERSION)
      .then((c) => Promise.all(shell.map(async (u) => {
        const href = new URL(u, self.location).href;
        const res = await fetch(new Request(href, { cache: "no-cache" }));
        if (!res.ok || !(await matches(res, sums.get(href)))) throw new Error(u + " isn't this version's");
        await c.put(href, res);
      })))
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

// The shell from the cache, the page too: a launch costs no round trip,
// and the page and its files are always one version. A newer version
// installs in the background and waits for the app's Reload. Navigations
// come first: any of them but the frame's is the app's page, whatever its
// path (a font's too). What isn't the shell's goes to the network, as
// without a worker.
self.addEventListener("fetch", (event) => {
  const req = event.request;
  const url = new URL(req.url);
  if (req.method !== "GET" || url.origin !== self.location.origin) return;
  if (req.mode === "navigate") {
    if (url.pathname !== FRAME_PATH) event.respondWith(kept(VERSION, page, sums.get(page), page));
    return;
  }
  if (url.pathname.startsWith(FONTS_PATH) && url.pathname.endsWith(".woff2")) {
    event.respondWith(fallbackFont(req, url));
    return;
  }
  const href = url.origin + url.pathname + url.search;
  if (sums.has(href)) event.respondWith(kept(VERSION, href, sums.get(href), req));
});

// kept answers href from cache name if the entry there is the server's own
// answer at href (not one a script made) and its body's SHA-256 is sum;
// otherwise it drops the entry and fetches from (a request or a URL),
// keeping that answer only if it is whole, the server's, and matches.
async function kept(name, href, sum, from) {
  const cache = await caches.open(name);
  const hit = await cache.match(href);
  if (hit) {
    if (hit.type === "basic" && hit.url === href && (await matches(hit, sum))) return hit;
    await cache.delete(href);
  }
  const res = await fetch(from);
  if (res.status === 200 && res.type === "basic" && res.url === href && (await matches(res, sum))) {
    await cache.put(href, res.clone());
  }
  return res;
}

// matches says whether res's body has SHA-256 sum (hex), reading a copy.
async function matches(res, sum) {
  if (!sum) return false;
  const digest = await crypto.subtle.digest("SHA-256", await res.clone().arrayBuffer());
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("") === sum;
}

// A fallback font from its cache, else from the relay; kept only when the
// build knows its sum. A name it doesn't know goes to the network.
async function fallbackFont(req, url) {
  const sum = (await fontSums())[url.pathname.slice(FONTS_PATH.length)];
  return sum ? kept(FONTS, url.origin + url.pathname, sum, req) : fetch(req);
}

// The fallback fonts' sums, read once from the shell (checked like any
// file of it); none when they can't be read, so nothing is kept.
let fontSumsRead;
function fontSums() {
  if (!FONT_SUMS) return Promise.resolve({});
  const href = new URL(FONT_SUMS, self.location).href;
  fontSumsRead ??= kept(VERSION, href, sums.get(href), href)
    .then((res) => (res.ok ? res.json() : {}))
    .catch(() => ({}))
    .then((m) => {
      if (Object.keys(m).length === 0) fontSumsRead = undefined; // asked again next time
      return m;
    });
  return fontSumsRead;
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
