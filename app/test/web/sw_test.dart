// The service worker (web/sw.js) in a real browser: its handlers run in
// the page against the browser's own Cache Storage and crypto, with a
// stand-in network, so what a script once run on the app's origin (or one
// altered answer) left in the caches can be checked against what it
// serves. Run with: flutter test --platform chrome test/web
@TestOn('browser')
library;

import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter_test/flutter_test.dart';

/// Reads web/sw.js in the VM (flutter test runs in app/); a hybrid
/// isolate resolves no packages, so the channel is untyped.
const _source = '''
import 'dart:io';
void hybridMain(dynamic channel) {
  channel.sink.add(File('web/sw.js').readAsStringSync());
}
''';

/// Runs one scenario of the worker, made from `src`, and gives what it
/// saw. The worker's `self` is a stand-in whose handlers the scenario
/// calls; its place is beside this page, so "./" is the page's folder.
const _harness = '''
(async (src, scenario) => {
  const enc = new TextEncoder();
  const hex = async (b) => [...new Uint8Array(await crypto.subtle.digest("SHA-256", typeof b === "string" ? enc.encode(b) : b))]
    .map((x) => x.toString(16).padStart(2, "0")).join("");
  const base = new URL("sw.js", location.href);
  const page = new URL("./", base).href;
  const main = new URL("main.js", base).href;
  const font = new URL("assets/fonts/fallback/noto/x.woff2", base).href;
  const other = new URL("assets/fonts/fallback/noto/y.woff2", base).href;
  const fontSums = new URL("assets/fonts/fallback-1.json", base).href;
  const tag = "t" + Math.random().toString(36).slice(2);
  const version = tag + "-shell", fonts = tag + "-fonts";
  const network = new Map([[page, "<p>the page</p>"], [main, "honest()"], [font, "FONT"], [other, "OTHER"],
    [fontSums, JSON.stringify({ "noto/x.woff2": await hex("FONT") })]]);
  let offline = false;
  const fetch = async (r) => {
    if (offline) throw new TypeError("offline");
    const href = String(typeof r === "string" ? r : r.url);
    return network.has(href) ? new Response(network.get(href)) : new Response("missing", { status: 404 });
  };
  const sums = { "./": await hex(network.get(page)), "main.js": await hex("honest()"),
    "assets/fonts/fallback-1.json": await hex(network.get(fontSums)) };
  let code = src;
  const put = (from, to, required) => {
    if (!code.includes(from)) { if (required) throw new Error("sw.js has no " + from); return; }
    code = code.replace(from, to);
  };
  put('const VERSION = "nushi-dev";', "const VERSION = " + JSON.stringify(version) + ";", true);
  put('const SHELL = ["./"];', 'const SHELL = ["./", "main.js"];', true);
  put('const FONTS = "nushi-fonts-dev";', "const FONTS = " + JSON.stringify(fonts) + ";", true);
  put("const SUMS = {};", "const SUMS = " + JSON.stringify(sums) + ";", false);
  put('const FONT_SUMS = "";', 'const FONT_SUMS = "assets/fonts/fallback-1.json";', false);
  const on = {};
  const self = { location: base, addEventListener: (t, f) => { on[t] = f; },
    registration: { active: null }, skipWaiting() {}, clients: { claim() {} } };
  new Function("self", "caches", "fetch", code)(self, caches, fetch);

  // A fetch event; a navigation's request is a stand-in (no page can make
  // one), which reads as its URL as a Request would.
  const get = async (href, mode) => {
    const request = mode === "navigate" ? { url: href, method: "GET", mode, toString: () => href } : new Request(href);
    let answer;
    on.fetch({ request, respondWith: (p) => { answer = p; } });
    if (!answer) return null;
    try { return await (await answer).text(); } catch (e) { return "error"; }
  };
  const kept = async (name, href) => {
    const hit = await (await caches.open(name)).match(href);
    return hit ? hit.text() : null;
  };
  const plant = async (name, href, body, type) =>
    (await caches.open(name)).put(href, new Response(body, { headers: { "Content-Type": type || "text/html" } }));
  const out = {};
  try {
    switch (scenario) {
      case "planted page":
        await plant(version, page, "<script>evil()</script>");
        out.served = await get(page, "navigate");
        out.kept = await kept(version, page);
        break;
      case "altered at install": {
        network.set(main, "altered()");
        let done;
        on.install({ waitUntil: (p) => { done = p; } });
        out.installed = await done.then(() => true, () => false);
        out.kept = await kept(version, main);
        break;
      }
      case "font cache navigation":
        await plant(fonts, font, "<script>evil()</script>");
        out.served = await get(font, "navigate");
        break;
      case "planted font":
        await plant(fonts, font, "evil", "font/woff2");
        out.served = await get(font);
        out.kept = await kept(fonts, font);
        break;
      case "unknown font":
        out.served = await get(other);
        out.kept = await kept(fonts, other);
        break;
      case "honest hit offline": {
        // A real answer from this origin, as the worker keeps them.
        const here = location.href.split("#")[0];
        const real = await globalThis.fetch(here);
        const body = await real.clone().arrayBuffer();
        sums[here] = await hex(body);
        code = src; // again, with this page among the shell's sums
        put('const VERSION = "nushi-dev";', "const VERSION = " + JSON.stringify(version) + ";", true);
        put('const FONTS = "nushi-fonts-dev";', "const FONTS = " + JSON.stringify(fonts) + ";", true);
        put("const SUMS = {};", "const SUMS = " + JSON.stringify(sums) + ";", false);
        new Function("self", "caches", "fetch", code)(self, caches, fetch);
        await (await caches.open(version)).put(here, real);
        offline = true;
        out.served = (await get(here)) === new TextDecoder().decode(body);
        break;
      }
    }
  } finally {
    await caches.delete(version);
    await caches.delete(fonts);
  }
  return JSON.stringify(out);
})
''';

void main() {
  late String src;
  setUpAll(() async {
    final channel = spawnHybridCode(_source);
    src = await channel.stream.first as String;
  });

  Future<Map<String, Object?>> run(String scenario) async {
    final f = globalContext.callMethod<JSFunction>('eval'.toJS, _harness.toJS);
    final out =
        await (f.callAsFunction(null, src.toJS, scenario.toJS)!
                as JSPromise<JSString>)
            .toDart;
    return (jsonDecode(out.toDart) as Map).cast<String, Object?>();
  }

  test('a page a script planted in the cache is dropped, not served', () async {
    expect(await run('planted page'), {
      'served': '<p>the page</p>',
      'kept': null,
    });
  });

  test("a file that isn't the build's fails the install", () async {
    expect(await run('altered at install'), {'installed': false, 'kept': null});
  });

  test('the fonts cache never answers a navigation', () async {
    expect((await run('font cache navigation'))['served'], '<p>the page</p>');
  });

  test('a planted font is dropped and fetched again', () async {
    expect(await run('planted font'), {'served': 'FONT', 'kept': null});
  });

  test("a font the build doesn't know is fetched, never kept", () async {
    expect(await run('unknown font'), {'served': 'OTHER', 'kept': null});
  });

  test('an answer the worker kept is served offline', () async {
    expect(await run('honest hit offline'), {'served': true});
  });
}
