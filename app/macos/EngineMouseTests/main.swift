// What Flutter's engine has been told of the mouse, and when the guard tells
// it a release or an end it never had (Runner/EngineMouse.swift, ADR 0080),
// built with it by `make test-window`. Each sequence is the engine's calls
// as NushiViewController makes them; `held` is NSEvent.pressedMouseButtons,
// which runs ahead of the events still queued.
import Foundation

var failed = 0

func expect<T: Equatable>(_ got: T, _ want: T, _ what: String, line: Int = #line) {
  guard got != want else { return }
  failed += 1
  print("FAIL line \(line): \(what): got \(got), want \(want)")
}

let left = 0, right = 1, middle = 2, back = 3
let none: UInt64 = 0
func held(_ n: Int...) -> UInt64 { n.reduce(0) { $0 | EngineMouse.bit($1) } }

/// A press of [n] seen and handed on, as the controller does: its stale
/// buttons let go first, each owed.
func press(_ m: inout EngineMouse, _ n: Int, held h: UInt64) -> (letGo: [Int], phase: EngineMouse.Phase) {
  let stale = m.real(pressed: n, held: h)
  for s in stale { _ = m.letGo(s, owing: s != n) }
  return (stale, m.pressed(n))
}

/// A real release handed on, unless the engine had one made up.
func release(_ m: inout EngineMouse, _ n: Int) -> EngineMouse.Phase? {
  m.real(released: n) ? m.released(n) : nil
}

for n in [left, right, middle, back] {
  let name = buttonName(n)
  do {
    // A press and its release: nothing owed, ever.
    var m = EngineMouse()
    expect(m.entered(), .add, "\(name): the pointer comes in")
    expect(m.moved(), .hover, "\(name): a hover")
    expect(press(&m, n, held: held(n)).phase, .down, "\(name): a press is a down")
    expect(m.stale(held: held(n)), [], "\(name): held: nothing stale")
    expect(m.moved(), .move, "\(name): a drag")
    expect(release(&m, n), .up, "\(name): its release is an up")
    expect(m.stale(held: none), [], "\(name): nothing stale after")
    expect(m.isDown, false, "\(name): no press")
  }
  do {
    // The release never came (a window drag, a menu's tracking took it).
    // Without the guard every move would be a drag with nothing held.
    var m = EngineMouse()
    _ = press(&m, n, held: held(n))
    expect(m.moved(), .move, "\(name): unguarded, a move with nothing held is a drag")
    // The pointer moves with no button: the guard lets it go, once.
    expect(m.stale(held: none), [n], "\(name): stale as the pointer moves")
    expect(m.letGo(n), .up, "\(name): the made-up release is an up")
    expect(m.moved(), .hover, "\(name): then a move is a hover")
    expect(m.stale(held: none), [], "\(name): let go once")
    // Its real release, if it comes after all, is dropped: no second up,
    // no click.
    expect(m.owes(n), true, "\(name): the real release is owed a drop")
    expect(release(&m, n), nil, "\(name): the late real release is dropped")
    expect(m.owes(n), false, "\(name): dropped once")
  }
  do {
    // The release never came and the next press of the same button did:
    // unguarded, the engine would send it as a move of the old press.
    var unguarded = EngineMouse()
    _ = unguarded.pressed(n)
    expect(unguarded.pressed(n), .move, "\(name): unguarded, the next press is a move")
    var m = EngineMouse()
    _ = press(&m, n, held: held(n))
    let next = press(&m, n, held: held(n))
    expect(next.letGo, [n], "\(name): the old press let go first")
    expect(next.phase, .down, "\(name): the next press is a down")
    // A real press clears what was owed: its own release goes on.
    expect(release(&m, n), .up, "\(name): the new press's release goes on")
  }
  do {
    // A made-up release, then a new real press before the old release
    // came: the release that comes is the new press's, not dropped.
    var m = EngineMouse()
    _ = press(&m, n, held: held(n))
    for s in m.stale(held: none) { _ = m.letGo(s) }
    _ = press(&m, n, held: held(n))
    expect(release(&m, n), .up, "\(name): a new press's release after a made-up one goes on")
  }
  do {
    // The release still queued: the live state shows it up, but a look
    // between events waits for a second look, and an event between clears
    // it. A held button is never stale.
    var m = EngineMouse()
    _ = press(&m, n, held: held(n))
    expect(m.look(held: held(n)), [], "\(name): held: no look finds it")
    expect(m.look(held: none), [], "\(name): one look isn't enough")
    expect(release(&m, n), .up, "\(name): the queued release comes")
    expect(m.look(held: none), [], "\(name): nothing for the second look")
    expect(m.owes(n), false, "\(name): and nothing owed")
    _ = press(&m, n, held: held(n))
    expect(m.look(held: none), [], "\(name): a first look")
    expect(m.moved(), .move, "\(name): an event between")
    expect(m.look(held: none), [], "\(name): starts the looks over")
    expect(m.look(held: none), [n], "\(name): two looks in a row with no event: stale")
  }
  do {
    // The pointer left the view with the button held, and the release was
    // lost: the made-up release also removes the pointer, as a real one.
    var m = EngineMouse()
    _ = m.entered()
    _ = press(&m, n, held: held(n))
    expect(m.exited(), .none, "\(name): out with a button held: removal waits")
    expect(m.pendingExit, true, "\(name): pending exit")
    expect(m.letGo(n), .up, "\(name): let go")
    expect(m.isAdded, false, "\(name): and removed")
    expect(m.entered(), .add, "\(name): back in, added again")
  }
}

do {
  // A right press whose release a context menu's tracking took leaves the
  // engine holding the right button: unguarded, a left press on a pane's
  // edge is a move of it (it does nothing), and each move with nothing
  // held a drag.
  var unguarded = EngineMouse()
  _ = unguarded.pressed(right)
  expect(unguarded.pressed(left), .move, "unguarded: a left press with a right stuck is a move")
  expect(unguarded.released(left), .move, "unguarded: and its release a move")
  var m = EngineMouse()
  _ = press(&m, right, held: held(right))
  let p = press(&m, left, held: held(left))
  expect(p.letGo, [right], "the stuck right let go before the left press")
  expect(p.phase, .down, "the left press is a down")
  expect(release(&m, left), .up, "its release an up")
  expect(release(&m, right), nil, "the right's late release dropped")
}
do {
  // A chord, all real: left held, right pressed and let go, then left.
  // Nothing is ever stale while held.
  var m = EngineMouse()
  _ = press(&m, left, held: held(left))
  let r = press(&m, right, held: held(left, right))
  expect(r.letGo, [], "a chord's second press lets nothing go")
  expect(r.phase, .move, "and is a move, as the engine has it")
  expect(release(&m, right), .move, "the second's release")
  expect(m.stale(held: held(left)), [], "left still held")
  expect(release(&m, left), .up, "the last release is the up")
}
do {
  // Live state ahead of the events: a right press whose release is still
  // queued as the left press is handled. The right is let go first (it is
  // up), and its real release, coming after, is dropped.
  var m = EngineMouse()
  _ = press(&m, right, held: held(right))
  let p = press(&m, left, held: held(left))
  expect(p.letGo, [right], "a right up in the live state")
  expect(release(&m, right), nil, "its queued release dropped")
  expect(release(&m, left), .up, "the left's goes on")
}
do {
  // A press elsewhere (a web view) while the engine holds a stale left:
  // the window's monitor lets it go before the press goes on.
  var m = EngineMouse()
  _ = press(&m, left, held: held(left))
  expect(m.real(pressed: left, held: held(left)), [left], "a press anywhere shows the old one ended")
}
do {
  // Buttons the engine can't hold.
  expect(EngineMouse.bit(64), 0, "no bit past 63")
  expect(EngineMouse.bit(-1), 0, "nor below 0")
  expect(EngineMouse.numbers(held(0, 3, 63)), [0, 3, 63], "numbers")
}

// Trackpad gestures: the engine's pan/zoom pointer.
do {
  var m = EngineMouse()
  expect(m.gesture(.scroll, .mayBegin), .panZoomStart, "two fingers down: a start")
  expect(m.gesture(.scroll, .began), .none, "the scroll begins: already started")
  expect(m.gesture(.scroll, .changed), .panZoomUpdate, "an update")
  expect(m.owesEnd(.scroll), true, "an end the engine would need")
  expect(m.gesture(.scroll, .ended), .panZoomEnd, "the end")
  expect(m.panZooming, false, "nothing going")
  expect(m.gesture(.scroll, .none, momentum: true), .none, "momentum: nothing")
  expect(m.gesture(.scroll, .none), .hover, "a wheel: a hover")
  expect(m.gesture(.scroll, .cancelled), .none, "a cancel with nothing going is ignored")
}
do {
  // A pinch whose end the engine never had holds back every scroll's end:
  // the engine's gesture stays going, and the next scroll is more of it.
  var m = EngineMouse()
  _ = m.gesture(.magnify, .began)
  _ = m.gesture(.scroll, .began)
  expect(m.gesture(.scroll, .ended), .none, "a scroll's end held back by the pinch")
  expect(m.gesture(.scroll, .began), .none, "the next scroll starts nothing")
  expect(m.owesEnd(.magnify), true, "the pinch's end is owed")
  expect(m.gesture(.magnify, .ended), .none, "the pinch's end, the scroll begun again")
  expect(m.gesture(.scroll, .ended), .panZoomEnd, "then the scroll's end ends it")
}
do {
  // The end went to another view: the engine is owed it, and given it.
  var m = EngineMouse()
  _ = m.gesture(.scroll, .began)
  expect(m.owesEnd(.scroll), true, "begun, no end")
  expect(m.owesEnd(.magnify), false, "no pinch")
  expect(m.gesture(.scroll, .ended), .panZoomEnd, "the end handed on")
  expect(m.owesEnd(.scroll), false, "owed nothing")
}

// The engine these mirror: EngineMouse.swift and NushiViewController.swift
// copy FlutterViewController.mm's MouseState and its gesture phases as of
// this revision, and nothing else would notice the engine changing them.
// The repository names the engine it builds with in
// tools/webbuild/fonts.lock (make web stops until make web-fonts writes the
// new one after a Flutter upgrade), and so does the Flutter on PATH, when
// there is one.
let mirrors = "deb287481e3ce9468f3434937ced4240a70539ca"

func engines() -> [(String, String)] {
  var found: [(String, String)] = []
  let repo = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
  let lock = repo.appendingPathComponent("tools/webbuild/fonts.lock")
  if let text = try? String(contentsOf: lock, encoding: .utf8) {
    for line in text.split(separator: "\n") where line.hasPrefix("engine ") {
      found.append((String(line.dropFirst("engine ".count)), lock.path))
    }
  } else {
    failed += 1
    print("FAIL: no \(lock.path) to read the engine's revision from")
  }
  for dir in (ProcessInfo.processInfo.environment["PATH"] ?? "").split(separator: ":") {
    let flutter = URL(fileURLWithPath: String(dir)).appendingPathComponent("flutter")
    guard FileManager.default.isExecutableFile(atPath: flutter.path) else { continue }
    let stamp = flutter.resolvingSymlinksInPath().deletingLastPathComponent()
      .appendingPathComponent("cache/engine.stamp")
    if let rev = try? String(contentsOf: stamp, encoding: .utf8) {
      found.append((rev.trimmingCharacters(in: .whitespacesAndNewlines), stamp.path))
    }
    break
  }
  return found
}

for (engine, from) in engines() where engine != mirrors {
  failed += 1
  print("""
    FAIL: Flutter's engine is \(engine) (\(from)), but EngineMouse mirrors \(mirrors).
      Re-read the new engine's FlutterViewController.mm (MouseState, how it
      sends a press, a move and a release, and a trackpad gesture's phases)
      against Runner/EngineMouse.swift and Runner/NushiViewController.swift,
      fix what changed, then set `mirrors` in EngineMouseTests/main.swift.
    """)
}

if failed > 0 {
  print("\(failed) engine mouse check(s) failed")
  exit(1)
}
print("engine mouse: ok")
