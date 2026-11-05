// What AppKit takes for its title bar in a window set up as Nushi's
// (Runner/TitleBar.swift, ADR 0080), built with it by `make test-window`.
// The window is never ordered in and no event is sent: AppKit is asked, by
// its own check, whether a point is on content that keeps its double
// clicks and drags (the theme frame's title-bar double-click recognizer and
// the title bar's release both ask it), and which view a press would hit.
import AppKit

var failed = 0

func expect<T: Equatable>(_ got: T, _ want: T, _ what: String, line: Int = #line) {
  guard got != want else { return }
  failed += 1
  print("FAIL line \(line): \(what): got \(got), want \(want)")
}

/// An opaque view, as FlutterView is, that takes presses and says nothing
/// of the title bar.
final class Content: NSView {
  override var isOpaque: Bool { true }
  override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// A window as MainFlutterWindow makes it, its content [covered] or not.
func window(covered: Bool) -> (NSWindow, Content) {
  let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
                   styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: true)
  w.isReleasedWhenClosed = false
  let wrapper = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
  let content = Content(frame: wrapper.bounds)
  content.autoresizingMask = [.width, .height]
  wrapper.addSubview(content)
  w.contentView = wrapper
  w.titlebarAppearsTransparent = true
  w.titleVisibility = .hidden
  w.styleMask.insert(.fullSizeContentView)
  if covered { TitleBarCover.cover(wrapper) }
  return (w, content)
}

typealias PointCheck = @convention(c) (AnyObject, Selector, NSPoint) -> Bool
let onContent = NSSelectorFromString("_pointCoincidesWithOpaqueSubview:")

/// Whether AppKit counts [fromTop] points below the window's top, in its
/// middle, as content that keeps its clicks rather than its title bar.
func isContent(_ w: NSWindow, fromTop: CGFloat) -> Bool? {
  guard let frame = w.contentView?.superview, frame.responds(to: onContent) else { return nil }
  let p = frame.convert(NSPoint(x: 400, y: w.frame.height - fromTop), from: nil)
  return unsafeBitCast(frame.method(for: onContent), to: PointCheck.self)(frame, onContent, p)
}

_ = NSApplication.shared
NSApp.setActivationPolicy(.prohibited)

let (bare, _) = window(covered: false)
let strip = bare.frame.height - bare.contentLayoutRect.height
expect(strip >= 22, true, "a title bar's strip under the transparent title bar (\(strip) points)")
if isContent(bare, fromTop: 16) == nil {
  // macOS 26's AppKit (CI's) has no such check to ask; from 27 on, a
  // missing one means AppKit renamed or dropped it: the cover may no
  // longer work, so a double click on a header's button may zoom the
  // window again.
  let os = ProcessInfo.processInfo.operatingSystemVersion
  if os.majorVersion >= 27 {
    failed += 1
    print("FAIL: AppKit no longer answers \(NSStringFromSelector(onContent)); check TitleBarCover")
  } else {
    print("title bar: macOS \(os.majorVersion) has no \(NSStringFromSelector(onContent)), not asked")
  }
}
let asks = isContent(bare, fromTop: 16) != nil

// Uncovered, an opaque content view in the strip is AppKit's title bar
// (what zoomed the window on a double click on a header's button).
if asks { expect(isContent(bare, fromTop: 16), false, "uncovered: the strip is the title bar's") }

// Covered, all of the strip is content's, high and low in it.
let (covered, content) = window(covered: true)
for top in [2.0, 16, strip - 2] where asks {
  expect(isContent(covered, fromTop: top), true, "covered: \(top) points from the top is content")
}

// The cover takes no press: the content does, in the strip and below it,
// and the traffic lights keep theirs.
let frame = covered.contentView!.superview!
for top in [16.0, strip + 20] {
  let p = frame.convert(NSPoint(x: 400, y: covered.frame.height - top), from: nil)
  expect(frame.hitTest(p) === content, true, "covered: a press \(top) points from the top is the content's")
}
if let close = covered.standardWindowButton(.closeButton), let bar = close.superview {
  let p = frame.convert(bar.convert(NSPoint(x: close.frame.midX, y: close.frame.midY), to: nil), from: nil)
  expect(frame.hitTest(p).map { $0 === close || $0.isDescendant(of: close) } ?? false, true, "the close button keeps its press")
} else {
  failed += 1
  print("FAIL: no close button")
}

// HeaderDrag: which of a header's pans move the window.
func moves(_ event: NSEvent.EventType = .leftMouseDragged, held: Bool = true, began: TimeInterval? = 10,
           clicks: Int = 1, moved: CGFloat = 2) -> Bool {
  HeaderDrag.moves(event: event, held: held, began: began, downAt: 10, clicks: clicks, moved: moved)
}
expect(moves(), true, "a press held, dragged")
expect(moves(.leftMouseDown, moved: 0), true, "a press held, not moved yet")
expect(moves(began: nil), true, "no time said")
expect(moves(began: 9.9995), true, "the engine's rounding")
expect(moves(held: false), false, "let go")
expect(moves(.leftMouseUp), false, "a release current")
expect(moves(began: 9), false, "a later press held")
// A double click's second press: its release is the header's double click,
// until it goes past a click's slop; then it's a drag, as a title bar's.
expect(moves(clicks: 2), false, "a second press moved 2 points")
expect(moves(clicks: 3, moved: 2), false, "a third press moved 2 points")
expect(moves(clicks: 2, moved: HeaderDrag.clickSlop), false, "a second press at the slop")
expect(moves(clicks: 2, moved: 20), true, "a second press moved 20 points")
expect(moves(clicks: 3, moved: 20), true, "a third press moved 20 points")
expect(moves(held: false, clicks: 2, moved: 20), false, "a second press let go")

if failed > 0 {
  print("\(failed) title bar check(s) failed")
  exit(1)
}
print("title bar: ok")
