//
//  WindUpView.swift
//  Intentio
//

import SwiftUI
import SwiftData

struct WindUpView: View {
    @Query(sort: \TaskItem.order, order: .forward) private var tasks: [TaskItem]
    @Binding var isButtonPressed: Bool
    
    @State private var isComplete = false
    
    private var pendingTasks: [TaskItem] {
        tasks.filter { !$0.isFinished }
    }
    
    private var messageLines: [String] {
        let topTasks = pendingTasks.prefix(3)
        if topTasks.isEmpty {
            return [
                "Nice. No pending tasks.",
                "Feel free to start adding them now."
            ]
        } else {
            var lines = ["Your top priorities today:"]
            for (index, task) in topTasks.enumerated() {
                lines.append("\(index + 1). \(task.text)")
            }
            return lines
        }
    }
    
    var body: some View {
        ZStack {
            Color.intentioBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                TypewriterText(
                    lines: messageLines,
                    charInterval: 0.04,
                    linePause: 0.6,
                    isActive: $isButtonPressed
                ) { _ in }
                onComplete: {
                    withAnimation(.easeInOut(duration: 0.5)) {
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
