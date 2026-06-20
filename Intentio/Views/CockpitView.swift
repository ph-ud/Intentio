//
//  CockpitView.swift
//  Intentio
//

import SwiftUI
import SwiftData

struct CockpitView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskItem.order, order: .forward) private var tasks: [TaskItem]
    
    var onFocus: (TaskItem) -> Void
    
    @State private var showingAddField = false
    @State private var newTaskText = ""
    @State private var selectedTask: TaskItem?
    @FocusState private var addFieldFocused: Bool
    
    private var pendingTasks: [TaskItem] {
        tasks.filter { !$0.isFinished }
    }
    
    var body: some View {
        ZStack {
            Color.intentioBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                
                taskList
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                
                Spacer()
                
                addButton
                    .padding(.horizontal, 24)
                    .padding(.bottom, IntentioLayout.buttonReservedHeight)
            }
            
            TopSheet(item: $selectedTask) { task in
                TaskDetailSheet(task: task) {
                    selectedTask = nil
                }
            }
        }
    }
    
    private var header: some View {
        Text("What does your day look like?")
            .font(.system(.title2, design: .serif))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }
    
    private var taskList: some View {
        List {
            if showingAddField {
                HStack(spacing: 12) {
                    TextField("New intention", text: $newTaskText, axis: .vertical)
                        .font(.system(.body, design: .serif))
                        .focused($addFieldFocused)
                        .onSubmit {
                            addTask()
                        }
                    
                    Button(action: addTask) {
                        Image(systemName: "checkmark")
                            .foregroundStyle(Color.intentioButton)
                    }
                    .disabled(newTaskText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .listRowBackground(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.35))
                )
                .listRowSeparator(.hidden)
            }
            
            ForEach(pendingTasks) { task in
                Button(action: { selectedTask = task }) {
                    HStack {
                        Text(task.text)
                            .font(.system(.body, design: .serif))
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "line.3.horizontal")
                            .foregroundStyle(Color.intentioButton.opacity(0.4))
                    }
                    .padding(.vertical, 8)
                }
                .listRowBackground(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.25))
                )
                .listRowSeparator(.hidden)
            }
            .onMove(perform: moveTasks)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
    
    private var addButton: some View {
        HStack {
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    showingAddField.toggle()
                    if showingAddField {
                        addFieldFocused = true
                    } else {
                        newTaskText = ""
                    }
                }
            }) {
                Image(systemName: showingAddField ? "xmark" : "plus")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(Color.intentioButton)
                    .frame(width: 56, height: 56)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.35))
                    )
            }
            
            Spacer()
        }
    }
    
    private func addTask() {
        let trimmed = newTaskText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let maxOrder = pendingTasks.map(\.order).max() ?? -1
        let task = TaskItem(text: trimmed, order: maxOrder + 1)
        modelContext.insert(task)
        
        newTaskText = ""
        addFieldFocused = true
    }
    
    private func moveTasks(from source: IndexSet, to destination: Int) {
        var reordered = pendingTasks
        reordered.move(fromOffsets: source, toOffset: destination)
        
        for (index, task) in reordered.enumerated() {
            task.order = index
        }
        
        try? modelContext.save()
    }
}

private struct TaskDetailSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var task: TaskItem
    var onClose: () -> Void
    
    @State private var noteText = ""
    @FocusState private var noteFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                Text(task.text)
                    .font(.system(.title2, design: .serif))
                    .lineLimit(nil)

                Spacer(minLength: 12)

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.intentioButton.opacity(0.6))
                }
            }

            TextEditor(text: $noteText)
                .font(.system(.body, design: .serif))
                .scrollContentBackground(.hidden)
                .frame(height: 160)
                .focused($noteFocused)
                .onChange(of: noteText) { _, newValue in
                    task.note = newValue
                }
                .placeholder(when: noteText.isEmpty) {
                    Text("Notes for this intention...")
                        .font(.system(.body, design: .serif))
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                        .padding(.leading, 4)
                }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            noteText = task.note ?? ""
            noteFocused = true
        }
    }
}

private extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .topLeading,
        @ViewBuilder placeholder: () -> Content
    ) -> some View {
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}
