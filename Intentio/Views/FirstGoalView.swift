//
//  FirstGoalView.swift
//  Intentio
//

import SwiftUI
import SwiftData

struct FirstGoalView: View {
    @Environment(\.modelContext) private var modelContext
    var onComplete: () -> Void
    
    @State private var goalText = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        ZStack {
            Color.intentioBackground.ignoresSafeArea()
            
            VStack(spacing: 24) {
                Spacer()
                
                Text("Start with what you want to achieve.")
                    .font(.system(.title2, design: .serif))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                TextField("", text: $goalText, axis: .vertical)
                    .font(.system(.title3, design: .serif))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .focused($isFocused)
                    .onSubmit {
                        saveGoal()
                    }
                
                Spacer()
                
                Button(action: saveGoal) {
                    Text(goalText.isEmpty ? "Skip" : "Begin")
                        .font(.system(.body, design: .serif))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(
                            Capsule()
                                .fill(Color.intentioButton.opacity(0.08))
                        )
                }
                .padding(.bottom, 80)
            }
            .padding(.top, 80)
        }
        .onAppear {
            isFocused = true
        }
    }
    
    private func saveGoal() {
        if !goalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let task = TaskItem(text: goalText.trimmingCharacters(in: .whitespacesAndNewlines), order: 0)
            modelContext.insert(task)
        }
        ShiftState.hasCompletedOnboarding = true
        onComplete()
    }
}
