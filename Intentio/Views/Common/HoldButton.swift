//
//  HoldButton.swift
//  Intentio
//

import SwiftUI

enum IntentioLayout {
    /// Size of the persistent hold button's tappable frame.
    static let buttonSize: CGFloat = 160

    /// Distance from the bottom safe area to the bottom edge of the button.
    /// Kept identical across every screen so the button never drifts.
    static let buttonBottomOffset: CGFloat = 56

    /// Vertical space the persistent button occupies above the bottom safe area.
    /// Screens with bottom-anchored content use this to avoid overlap.
    static let buttonReservedHeight: CGFloat = 240
}

struct HoldButton: View {
    @Binding var progress: Double
    @Binding var isPressed: Bool
    var holdDuration: TimeInterval = 2.5
    var onTap: () -> Void = {}
    var onDoubleTap: () -> Void = {}
    var onHoldComplete: () -> Void = {}
    var onPressStart: (() -> Void)?
    var onPressEnd: (() -> Void)?

    @State private var startDate = Date()
    @State private var pressStartTime: Date?
    @State private var holdCompleted = false
    @State private var tapCount = 0
    @State private var tapTimer: Timer?
    @State private var progressTimer: Timer?

    private let impact = UIImpactFeedbackGenerator(style: .soft)
    private let success = UINotificationFeedbackGenerator()

    var body: some View {
        // TimelineView drives the idle morph off the system display link, so the
        // shape animates continuously without ever writing to @State or the
        // progress binding. The progress timer (below) only runs while pressed.
        TimelineView(.animation) { context in
            let morphTime = context.date.timeIntervalSince(startDate)
            OrganicBlob(progress: progress, morphTime: morphTime)
                .fill(Color.intentioButton)
        }
        .frame(width: IntentioLayout.buttonSize, height: IntentioLayout.buttonSize)
        .contentShape(Circle())
        .scaleEffect(isPressed ? 0.92 : 1.0)
        .animation(.easeOut(duration: 0.2), value: isPressed)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Hold to continue")
        .accessibilityValue("\(Int(progress * 100)) percent")
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onChanged(handleDragChanged)
                .onEnded { _ in handleRelease() }
        )
        .onAppear {
            impact.prepare()
            success.prepare()
        }
        .onDisappear(perform: teardown)
    }

    // MARK: - Lifecycle

    private func teardown() {
        stopProgressTimer()
        tapTimer?.invalidate()
        tapTimer = nil
    }

    // MARK: - Progress

    /// A 60 Hz timer scoped to the duration of a press. Added to `.common` mode
    /// so it keeps firing even while the run loop is in a tracking mode.
    private func startProgressTimer() {
        stopProgressTimer()
        let timer = Timer(timeInterval: 1 / 60, repeats: true) { _ in
            updateProgressIfNeeded()
        }
        RunLoop.main.add(timer, forMode: .common)
        progressTimer = timer
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    private func updateProgressIfNeeded() {
        guard let start = pressStartTime, !holdCompleted else { return }
        let elapsed = Date().timeIntervalSince(start)
        let newProgress = min(1.0, elapsed / holdDuration)
        progress = newProgress

        if newProgress >= 1.0 {
            holdCompleted = true
            stopProgressTimer()
            success.notificationOccurred(.success)
            onHoldComplete()
        }
    }

    // MARK: - Touch handling

    private func handleDragChanged(_ value: DragGesture.Value) {
        if pressStartTime == nil {
            beginPress()
        }

        let location = value.location
        let center = CGPoint(x: IntentioLayout.buttonSize / 2, y: IntentioLayout.buttonSize / 2)
        let distance = hypot(location.x - center.x, location.y - center.y)
        let hitSlop: CGFloat = 30

        if distance > (IntentioLayout.buttonSize / 2) + hitSlop {
            handleRelease()
        }
    }

    private func beginPress() {
        pressStartTime = Date()
        holdCompleted = false
        isPressed = true
        impact.prepare()
        impact.impactOccurred(intensity: 0.5)
        onPressStart?()
        startProgressTimer()
    }

    private func handleRelease() {
        let wasPressed = pressStartTime != nil
        let completed = holdCompleted
        pressStartTime = nil
        isPressed = false
        stopProgressTimer()
        onPressEnd?()

        if wasPressed {
            if !completed {
                registerTap()
                impact.impactOccurred(intensity: 0.3)
            }

            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                progress = 0
            }
        } else {
            // Very quick taps sometimes end before onChanged fires, so the press
            // phase is missing. Treat the release as a tap so the button still reacts.
            registerTap()
            impact.impactOccurred(intensity: 0.3)
        }
    }

    // MARK: - Tap / double-tap

    private func registerTap() {
        tapCount += 1

        if tapCount == 1 {
            let timer = Timer(timeInterval: 0.2, repeats: false) { _ in
                onTap()
                tapCount = 0
            }
            RunLoop.main.add(timer, forMode: .common)
            tapTimer = timer
        } else if tapCount == 2 {
            tapTimer?.invalidate()
            tapTimer = nil
            onDoubleTap()
            tapCount = 0
        }
    }
}

// MARK: - Organic blob shape

private struct OrganicBlob: Shape {
    var progress: Double
    var morphTime: Double

    // Only progress is interpolated by SwiftUI (the spring on release). morphTime
    // arrives fresh from the TimelineView each frame, so it needs no animation.
    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let baseRadius = min(rect.width, rect.height) / 2 * 0.82
        let pointCount = 12

        func radius(at angle: Double) -> Double {
            let idle = (sin(angle * 3 + morphTime) * 5
                     + sin(angle * 5 - morphTime * 1.3) * 3
                     + sin(angle * 2 + morphTime * 0.5) * 2.5) * 0.3

            // Pressing creates a rippling, water-drop distortion that grows with progress.
            let ripple = progress * 16 * sin(angle * 8 - morphTime * 4)
            let bulge = progress * progress * 10

            return baseRadius + idle + ripple + bulge
        }

        var points: [CGPoint] = []
        for i in 0..<pointCount {
            let angle = Double(i) / Double(pointCount) * 2 * .pi
            let r = radius(at: angle)
            points.append(CGPoint(
                x: center.x + cos(angle) * r,
                y: center.y + sin(angle) * r
            ))
        }

        var midpoints: [CGPoint] = []
        for i in 0..<pointCount {
            let current = points[i]
            let next = points[(i + 1) % pointCount]
            midpoints.append(CGPoint(
                x: (current.x + next.x) / 2,
                y: (current.y + next.y) / 2
            ))
        }

        var path = Path()
        path.move(to: midpoints[0])
        for i in 0..<pointCount {
            path.addQuadCurve(
                to: midpoints[(i + 1) % pointCount],
                control: points[(i + 1) % pointCount]
            )
        }
        path.closeSubpath()
        return path
    }
}
