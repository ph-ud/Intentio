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

    /// A single sinusoidal contribution to the blob's radius. The organic look
    /// comes from stacking several of these with unrelated lobe counts and drift
    /// speeds, so the outline never collapses into one clean, repeating wave.
    private struct Wave {
        var lobes: Double      // number of bumps around the circumference
        var drift: Double      // how fast those bumps travel over time
        var amplitude: Double  // bump depth, in points
        var phase: Double = 0  // fixed offset so layers don't all start aligned

        func offset(at angle: Double, time: Double) -> Double {
            sin(angle * lobes + time * drift + phase) * amplitude
        }
    }

    /// Resting motion: the button gently "breathes" while untouched.
    private static let idleWaves = [
        Wave(lobes: 3, drift:  1.0, amplitude: 1.50),
        Wave(lobes: 5, drift: -1.3, amplitude: 0.90),
        Wave(lobes: 2, drift:  0.5, amplitude: 0.75),
    ]

    /// Pressed distortion, scaled by `progress`: like the uneven rings a drop
    /// pushes across water. The mismatched lobe counts and drift speeds keep the
    /// ripples from ever lining up into a symmetric flower; the final 1-lobe wave
    /// adds a slow, lopsided lean.
    private static let rippleWaves = [
        Wave(lobes: 5, drift: -4.0, amplitude: 9, phase: 0.0),
        Wave(lobes: 7, drift:  2.7, amplitude: 5, phase: 1.3),
        Wave(lobes: 3, drift: -5.6, amplitude: 4, phase: 2.1),
        Wave(lobes: 1, drift: -1.7, amplitude: 3, phase: 0.6),
    ]

    /// Vertices sampled around the circle. High enough that the 7-lobe ripple
    /// renders smoothly instead of aliasing into a fake low-frequency wobble.
    private static let vertexCount = 16

    /// Resting radius as a fraction of the frame's half-extent.
    private static let radiusFraction = 0.82

    /// Extra swell under a sustained press, growing with progress².
    private static let pressSwell = 10.0

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let baseRadius = min(rect.width, rect.height) / 2 * Self.radiusFraction

        func radius(at angle: Double) -> Double {
            let idle = Self.idleWaves.reduce(0) { $0 + $1.offset(at: angle, time: morphTime) }
            let ripple = Self.rippleWaves.reduce(0) { $0 + $1.offset(at: angle, time: morphTime) }
            let swell = progress * progress * Self.pressSwell
            return baseRadius + idle + progress * ripple + swell
        }

        let vertexCount = Self.vertexCount
        var points: [CGPoint] = []
        for i in 0..<vertexCount {
            let angle = Double(i) / Double(vertexCount) * 2 * .pi
            let r = radius(at: angle)
            points.append(CGPoint(
                x: center.x + cos(angle) * r,
                y: center.y + sin(angle) * r
            ))
        }

        // Draw quad curves through the edge midpoints, using each vertex as the
        // control point, so the outline stays smooth and closed.
        var midpoints: [CGPoint] = []
        for i in 0..<vertexCount {
            let current = points[i]
            let next = points[(i + 1) % vertexCount]
            midpoints.append(CGPoint(
                x: (current.x + next.x) / 2,
                y: (current.y + next.y) / 2
            ))
        }

        var path = Path()
        path.move(to: midpoints[0])
        for i in 0..<vertexCount {
            path.addQuadCurve(
                to: midpoints[(i + 1) % vertexCount],
                control: points[(i + 1) % vertexCount]
            )
        }
        path.closeSubpath()
        return path
    }
}
