//
//  ShiftState.swift
//  Intentio
//

import Foundation

enum ShiftStateKeys {
    static let hasCompletedOnboarding = "hasCompletedOnboarding"
    static let lastShiftEndedAt = "lastShiftEndedAt"
}

final class ShiftState {
    static var hasCompletedOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: ShiftStateKeys.hasCompletedOnboarding) }
        set { UserDefaults.standard.set(newValue, forKey: ShiftStateKeys.hasCompletedOnboarding) }
    }
    
    static var lastShiftEndedAt: Date? {
        get { UserDefaults.standard.object(forKey: ShiftStateKeys.lastShiftEndedAt) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: ShiftStateKeys.lastShiftEndedAt) }
    }
    
    static var shouldWindUp: Bool {
        guard let last = lastShiftEndedAt else { return true }
        return !Calendar.current.isDate(last, inSameDayAs: Date())
    }
    
    static func endShift() {
        lastShiftEndedAt = Date()
    }
}
