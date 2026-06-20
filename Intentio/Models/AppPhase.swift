//
//  AppPhase.swift
//  Intentio
//

import Foundation

enum AppPhase: Equatable {
    case onboarding
    case firstGoal
    case windUp
    case cockpit
    case focus(TaskItem)
    case windDown
    case goodbye
}
