//
//  TypewriterText.swift
//  Intentio
//

import SwiftUI

/// Classic character-by-character typewriter — without the reflow jitter.
///
/// The full text is laid out from the very first frame as an invisible *sizer*,
/// so the block reserves its final size and never re-wraps or shifts while it
/// types. A perfectly-registered overlay then reveals characters one at a time
/// by ramping each glyph's alpha, with a soft fade on the newest character and
/// a blinking caret at the cursor position.
struct TypewriterText: View {
    let lines: [String]
    var charInterval: TimeInterval = 0.04
    var linePause: TimeInterval = 0.7
    var isActive: Binding<Bool>
    var onLineRevealed: ((Int) -> Void)?
    var onComplete: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var revealed = 0          // characters revealed, across all lines
    @State private var firedParagraphs = 0
    @State private var caretOn = true
    @State private var timer: Timer?
    @State private var caretTimer: Timer?
    @State private var didComplete = false

    /// Prefix sums of per-line character counts. `cum[p]` is the first global
    /// character index of line `p`; `cum.last` is the total character count.
    private var cum: [Int] {
        var sums = [0]
        for line in lines { sums.append(sums.last! + line.count) }
        return sums
    }

    private var total: Int { cum.last ?? 0 }

    /// Index of the line currently being typed (where the caret lives), or `nil`.
    private var activeLine: Int? {
        guard isActive.wrappedValue, !didComplete, revealed > 0 else { return nil }
        for p in lines.indices where revealed < cum[p + 1] {
            return p
        }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                TypingLine(
                    text: line,
                    revealed: min(max(revealed - cum[index], 0), line.count),
                    caret: activeLine == index && caretOn,
                    fadeWindow: reduceMotion ? 1 : 2
                )
            }
        }
        .font(.system(.title2, design: .serif))
        .foregroundStyle(.primary)
        .onAppear {
            startCaret()
            if isActive.wrappedValue && !didComplete {
                continueTyping()
            }
        }
        .onChange(of: lines) {
            reset()
            if isActive.wrappedValue {
                continueTyping()
            }
        }
        .onChange(of: isActive.wrappedValue) { _, active in
            if active && !didComplete {
                continueTyping()
            } else {
                timer?.invalidate()
                timer = nil
            }
        }
        .onDisappear {
            timer?.invalidate()
            caretTimer?.invalidate()
        }
    }

    private func reset() {
        timer?.invalidate()
        timer = nil
        revealed = 0
        firedParagraphs = 0
        didComplete = false
    }

    private func startCaret() {
        caretTimer?.invalidate()
        caretTimer = Timer.scheduledTimer(withTimeInterval: 0.55, repeats: true) { _ in
            caretOn.toggle()
        }
    }

    private func continueTyping() {
        guard !didComplete else { return }
        timer?.invalidate()
        typeNextCharacter()
    }

    private func typeNextCharacter() {
        guard isActive.wrappedValue, !didComplete else { return }

        guard revealed < total else {
            finish()
            return
        }

        revealed += 1
        caretOn = true
        fireParagraphCallbacks()

        guard revealed < total else {
            finish()
            return
        }

        // Pause at line breaks; otherwise a steady per-character cadence.
        let atLineBreak = cum.contains(revealed)
        let delay = atLineBreak ? linePause : charInterval

        timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { _ in
            typeNextCharacter()
        }
    }

    private func finish() {
        timer?.invalidate()
        timer = nil
        fireParagraphCallbacks()
        guard !didComplete else { return }
        didComplete = true
        onComplete?()
    }

    /// Fire `onLineRevealed` for each line that has become fully visible.
    private func fireParagraphCallbacks() {
        while firedParagraphs < lines.count, cum[firedParagraphs + 1] <= revealed {
            onLineRevealed?(firedParagraphs)
            firedParagraphs += 1
        }
    }
}

/// A single line of typed text. An invisible full-length copy fixes the layout;
/// the visible copy reveals characters by alpha and carries the caret.
private struct TypingLine: View {
    let text: String
    let revealed: Int
    let caret: Bool
    let fadeWindow: Double

    var body: some View {
        let chars = Array(text)

        // Invisible sizer holds the line's final size so nothing reflows.
        Text(text)
            .foregroundStyle(.clear)
            .overlay(alignment: .topLeading) {
                Text(revealedAttributedString(chars))
            }
    }

    private func revealedAttributedString(_ chars: [Character]) -> AttributedString {
        var result = AttributedString()

        for (i, ch) in chars.enumerated() {
            if i == revealed, caret {
                result.append(caretGlyph())
            }
            // Newest characters ramp in over `fadeWindow` ticks for a soft strike.
            let alpha = max(0, min(1, (Double(revealed) - Double(i)) / fadeWindow))
            var glyph = AttributedString(String(ch))
            glyph.foregroundColor = Color.primary.opacity(alpha)
            result.append(glyph)
        }

        if revealed >= chars.count, caret {
            result.append(caretGlyph())
        }

        return result
    }

    private func caretGlyph() -> AttributedString {
        var caret = AttributedString("\u{258F}") // ▏ left one-eighth block
        caret.foregroundColor = .primary
        return caret
    }
}
