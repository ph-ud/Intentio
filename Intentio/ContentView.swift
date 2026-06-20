//
//  ContentView.swift
//  Intentio
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskItem.order, order: .forward) private var tasks: [TaskItem]
    
    @State private var phase: AppPhase = .onboarding
    @State private var isAnimatingTransition = false
    
    // Persistent button state — survives screen transitions.
    @State private var buttonProgress: Double = 0
    @State private var isButtonPressed: Bool = false
    @State private var isKeyboardVisible: Bool = false
    
    // Focus task interaction state.
    @State private var focusConfirmation: FocusConfirmation = .none
    
    private var pendingTasks: [TaskItem] {
        tasks.filter { !$0.isFinished }
    }
    
    private var topTask: TaskItem? {
        pendingTasks.first
    }
    
    private var buttonIsVisible: Bool {
        if isKeyboardVisible { return false }
        switch phase {
        case .onboarding, .windUp, .cockpit, .focus, .windDown, .goodbye:
            return true
        case .firstGoal:
            return false
        }
    }
    
    private var buttonHoldDuration: TimeInterval {
        switch phase {
        case .onboarding:
            return 6.5
        case .windUp, .windDown:
            return 3.0
        case .cockpit:
            return 2.0
        case .goodbye:
            return 1.5
        case .focus:
            // Focus only uses taps; make hold very long to avoid accidental triggers.
            return 10.0
        default:
            return 2.5
        }
    }
    
    var body: some View {
        ZStack {
            // Persistent background so cross-fading screens never reveal the
            // window's white backing during a transition.
            Color.intentioBackground.ignoresSafeArea()

            // Background screen
            Group {
                switch phase {
                case .onboarding:
                    OnboardingView(isButtonPressed: $isButtonPressed)
                    
                case .firstGoal:
                    FirstGoalView {
                        transition(to: .cockpit)
                    }
                    
                case .windUp:
                    WindUpView(isButtonPressed: $isButtonPressed)
                    
                case .cockpit:
                    CockpitView(
                        onFocus: { task in
                            resetFocusState()
                            transition(to: .focus(task))
                        }
                    )
                    
                case .focus(let task):
                    FocusView(
                        task: task,
                        confirmation: $focusConfirmation,
                        onReturn: { transition(to: .cockpit) }
                    )
                    
                case .windDown:
                    WindDownView(isButtonPressed: $isButtonPressed)
                    
                case .goodbye:
                    GoodbyeView()
                }
            }
            .opacity(isAnimatingTransition ? 0 : 1)
            .scaleEffect(isAnimatingTransition ? 0.96 : 1)
            
            // Persistent button overlay
            if buttonIsVisible {
                GeometryReader { geometry in
                    VStack {
                        Spacer()
                        
                        if phase == .cockpit && isButtonPressed && buttonProgress < 1.0 {
                            Text("Did your shift finish? Keep holding.")
                                .font(.system(.callout, design: .serif))
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                                .padding(.bottom, 16)
                        }
                        
                        HoldButton(
                            progress: $buttonProgress,
                            isPressed: $isButtonPressed,
                            holdDuration: buttonHoldDuration,
                            onTap: handleButtonTap,
                            onDoubleTap: handleButtonDoubleTap,
                            onHoldComplete: handleButtonHoldComplete,
                            onPressStart: { },
                            onPressEnd: { handleButtonRelease(completed: buttonProgress >= 1.0) }
                        )
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.bottom, geometry.safeAreaInsets.bottom + IntentioLayout.buttonBottomOffset)
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .animation(.easeInOut(duration: 0.25), value: buttonIsVisible)
            }
        }
        .onAppear(perform: determineInitialPhase)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            isKeyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            isKeyboardVisible = false
        }
    }
    
    private func determineInitialPhase() {
        if !ShiftState.hasCompletedOnboarding {
            phase = .onboarding
        } else if ShiftState.shouldWindUp {
            phase = .windUp
        } else {
            phase = .cockpit
        }
    }
    
    private func transition(to newPhase: AppPhase, then afterSwap: (() -> Void)? = nil) {
        if case .focus = newPhase { } else {
            resetFocusState()
        }

        withAnimation(.easeInOut(duration: 0.35)) {
            isAnimatingTransition = true
        } completion: {
            phase = newPhase
            afterSwap?()
            withAnimation(.easeInOut(duration: 0.35)) {
                isAnimatingTransition = false
            }
        }
    }
    
    /// Used for transitions that happen while the button is still held, so
    /// the phase must change before the user can release.
    private func immediateTransition(to newPhase: AppPhase) {
        if case .focus = newPhase { } else {
            resetFocusState()
        }
        phase = newPhase
    }
    
    private func resetFocusState() {
        focusConfirmation = .none
    }
    
    private func handleButtonTap() {
        switch phase {
        case .cockpit:
            if let top = topTask {
                transition(to: .focus(top))
            }
        case .focus(let task):
            handleFocusTap(task: task)
        default:
            break
        }
    }
    
    private func handleButtonDoubleTap() {
        if case .focus(let task) = phase {
            handleFocusDoubleTap(task: task)
        }
    }
    
    private func handleFocusTap(task: TaskItem) {
        switch focusConfirmation {
        case .none:
            focusConfirmation = .returnToCockpit
        case .returnToCockpit:
            resetFocusState()
            transition(to: .cockpit)
        case .finishTask:
            focusConfirmation = .none
        }
    }
    
    private func handleFocusDoubleTap(task: TaskItem) {
        switch focusConfirmation {
        case .none, .returnToCockpit:
            focusConfirmation = .finishTask
        case .finishTask:
            finishFocusedTask(task)
            resetFocusState()
            transition(to: .cockpit)
        }
    }
    
    private func finishFocusedTask(_ task: TaskItem) {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        task.markFinished()
        try? modelContext.save()
    }
    
    private func handleButtonHoldComplete() {
        switch phase {
        case .cockpit:
            immediateTransition(to: .windDown)
        case .goodbye:
            immediateTransition(to: .windUp)
        default:
            break
        }
    }
    
    private func handleButtonRelease(completed: Bool) {
        switch phase {
        case .onboarding where completed:
            transition(to: .firstGoal)
        case .windUp where completed:
            transition(to: .cockpit)
        case .windDown where completed:
            ShiftState.endShift()
            // Clear after the swap so wind-down's summary doesn't recompute mid-fade.
            transition(to: .goodbye, then: clearFinishedTasks)
        default:
            break
        }
    }

    /// Removes completed tasks from the store at the end of a shift, after the
    /// wind-down summary has been shown. Pending tasks carry over to tomorrow.
    private func clearFinishedTasks() {
        for task in tasks where task.isFinished {
            modelContext.delete(task)
        }
        try? modelContext.save()
    }
}
