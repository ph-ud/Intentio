//
//  FocusView.swift
//  Intentio
//

import SwiftUI

enum FocusConfirmation {
    case none
    case returnToCockpit
    case finishTask
}

struct FocusView: View {
    let task: TaskItem
    @Binding var confirmation: FocusConfirmation
    var onReturn: () -> Void
    
    var body: some View {
        ZStack {
            Color.intentioBackground.ignoresSafeArea()
            
            VStack(spacing: 24) {
                Spacer()
                
                Text(task.text)
                    .font(.system(.largeTitle, design: .serif))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                if confirmation == .returnToCockpit {
                    Text("Tap the button again to return")
                        .font(.system(.body, design: .serif))
                        .foregroundStyle(.secondary)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                } else if confirmation == .finishTask {
                    Text("Double tap the button again to finish")
                        .font(.system(.body, design: .serif))
                        .foregroundStyle(.secondary)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
                
                Spacer()
            }
            .padding(.top, 80)
        }
    }
}
