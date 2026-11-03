import Cocoa
import FlutterMacOS

/// Spell check for the prompt box (lib/spell_check.dart, ADR 0083): the Mac's
/// own checker, with the languages and dictionary the user set. Nothing
/// leaves the Mac. One document tag for the app's run, so Ignore lasts until
/// it quits, across chats; `learn` writes the macOS user dictionary.
final class Spelling {
  private let checker = NSSpellChecker.shared
  private let tag = NSSpellChecker.uniqueSpellDocumentTag()

  func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    switch call.method {
    case "check":
      guard let words = call.arguments as? [String] else { return result(refused()) }
      check(words, result)
    case "guesses":
      guard let word = call.arguments as? String else { return result(refused()) }
      let whole = NSRange(location: 0, length: (word as NSString).length)
      result(checker.guesses(forWordRange: whole, in: word, language: checker.language(), inSpellDocumentWithTag: tag) ?? [])
    case "ignore":
      guard let word = call.arguments as? String else { return result(refused()) }
      checker.ignoreWord(word, inSpellDocumentWithTag: tag)
      result(nil)
    case "learn":
      guard let word = call.arguments as? String else { return result(refused()) }
      checker.learnWord(word)
      result(nil)
    default: result(FlutterMethodNotImplemented)
    }
  }

  /// Answers which of `words` are misspelled. The checker works off the main
  /// thread here, so a long list never holds up the window; each word on its
  /// own line, and a hit is mapped back to the whole line it's on.
  private func check(_ words: [String], _ result: @escaping FlutterResult) {
    let text = words.joined(separator: "\n") as NSString
    checker.requestChecking(
      of: text as String, range: NSRange(location: 0, length: text.length),
      types: NSTextCheckingResult.CheckingType.spelling.rawValue, options: nil, inSpellDocumentWithTag: tag
    ) { _, found, _, _ in
      let wrong = found.map { text.substring(with: text.lineRange(for: $0.range)).trimmingCharacters(in: .newlines) }
      DispatchQueue.main.async { result(wrong) }
    }
  }

  private func refused() -> FlutterError {
    FlutterError(code: "refused", message: "Not a word to check", details: nil)
  }
}
