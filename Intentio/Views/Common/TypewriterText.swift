//
//  TypewriterText.swift
//  Intentio
//

import SwiftUI

struct TypewriterText: View {
    let lines: [String]
    var charInterval: TimeInterval = 0.04
    var linePause: TimeInterval = 0.7
    var isActive: Binding<Bool>
    var onLineRevealed: ((Int) -> Void)?
    var onComplete: (() -> Void)?
    
    @State private var visibleLines: [String] = []
    @State private var currentLine: String = ""
    @State private var lineIndex = 0
    @State private var charIndex = 0
    @State private var timer: Timer?
    @State private var didComplete = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(visibleLines.indices, id: \.self) { index in
                Text(visibleLines[index])
            }
            
            if lineIndex < lines.count {
                Text(currentLine)
                    .opacity(currentLine.isEmpty ? 0 : 1)
            }
        }
        .font(.system(.title2, design: .serif))
        .foregroundStyle(.primary)
        .onAppear {
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
        }
    }
    
    private func reset() {
        timer?.invalidate()
        timer = nil
        visibleLines = []
        currentLine = ""
        lineIndex = 0
        charIndex = 0
        didComplete = false
    }
    
    private func continueTyping() {
        guard !didComplete else { return }
        timer?.invalidate()
        typeNextCharacter()
    }
    
    private func typeNextCharacter() {
        guard lineIndex < lines.count else {
            didComplete = true
            onComplete?()
            return
        }
        
        let line = lines[lineIndex]
        
        guard charIndex < line.count else {
            visibleLines.append(currentLine)
            onLineRevealed?(lineIndex)
            currentLine = ""
            lineIndex += 1
            charIndex = 0

            if lineIndex < lines.count {
                timer = Timer.scheduledTimer(withTimeInterval: linePause, repeats: false) { _ in
                    typeNextCharacter()
                }
            } else {
                didComplete = true
                onComplete?()
            }
            return
        }
        
        timer = Timer.scheduledTimer(withTimeInterval: charInterval, repeats: false) { _ in
            let stringIndex = line.index(line.startIndex, offsetBy: charIndex)
            currentLine.append(line[stringIndex])
            charIndex += 1
            typeNextCharacter()
        }
    }
}
