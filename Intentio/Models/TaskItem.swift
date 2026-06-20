//
//  TaskItem.swift
//  Intentio
//

import Foundation
import SwiftData

@Model
class TaskItem {
    var text: String
    var order: Int
    var note: String?
    var isFinished: Bool
    var finishedAt: Date?
    var createdAt: Date
    
    init(text: String, order: Int, note: String? = nil) {
        self.text = text
        self.order = order
        self.note = note
        self.isFinished = false
        self.finishedAt = nil
        self.createdAt = Date()
    }

    /// Marks the task complete and stamps the completion time. The single source
    /// of truth for finishing a task — call `save()` on the context afterwards.
    func markFinished(at date: Date = Date()) {
        isFinished = true
        finishedAt = date
    }
}
