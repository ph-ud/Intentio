//
//  OnboardingView.swift
//  Intentio
//

import SwiftUI

struct OnboardingView: View {
    @Binding var isButtonPressed: Bool
    
    @State private var isComplete = false
    
    private let messages = [
        "One thing at a time.",
        "No multitasking. No noise.",
        "Everything here is intentional.",
        "Hold the button to begin."
    ]
    
    var body: some View {
        ZStack {
            Color.intentioBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                TypewriterText(
                    lines: messages,
                    charInterval: 0.045,
                    linePause: 0.8,
                    isActive: $isButtonPressed
                ) { _ in }
                onComplete: {
                    withAnimation(.easeInOut(duration: 0.6)) {
                        isComplete = true
                    }
                }
                .padding(.horizontal, 40)
                
                Spacer()
                
                if isComplete {
                    Text("Lift your finger")
                        .font(.system(.body, design: .serif))
                        .padding(.bottom, IntentioLayout.buttonReservedHeight)
                }
                
                Spacer()
            }
        }
    }
}
