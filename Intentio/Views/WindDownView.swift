//
//  WindDownView.swift
//  Intentio
//

import SwiftUI
import SwiftData

struct WindDownView: View {
    @Query(sort: \TaskItem.finishedAt, order: .reverse) private var tasks: [TaskItem]
    @Binding var isButtonPressed: Bool
    
    @State private var isComplete = false
    
    private var finishedToday: [TaskItem] {
        tasks.filter { task in
            guard task.isFinished, let date = task.finishedAt else { return false }
            return Calendar.current.isDateInToday(date)
        }
    }
    
    private var messageLines: [String] {
        var lines = ["Great. Let's call it a day then."]
        
        if finishedToday.isEmpty {
            lines.append("You didn't finish anything today.")
            lines.append("That is okay.")
            lines.append("Rest is not the opposite of productivity.")
            lines.append("It is part of it.")
        } else {
            lines.append("You finished:")
            for task in finishedToday {
                lines.append("• \(task.text)")
            }
            lines.append("Now, let it go.")
        }
        
        return lines
    }
    
    var body: some View {
        ZStack {
            Color.intentioBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                TypewriterText(
                    lines: messageLines,
                    charInterval: 0.04,
                    linePause: 0.7,
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
