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

    // Local working copy that drives the list. Kept in sync with the query while
    // idle, and reordered on drop.
    @State private var rows: [TaskItem] = []

    // Live row positions, reported continuously via a preference key.
    @State private var rowFrames: [PersistentIdentifier: CGRect] = [:]

    // Drag state. `frozenFrames` is a snapshot of the resting layout taken at
    // drag-start, so target calculations never read the rows we're busy moving.
    @State private var draggingID: PersistentIdentifier?
    @State private var dragTranslation: CGFloat = 0
    @State private var frozenFrames: [PersistentIdentifier: CGRect] = [:]
    @State private var dragFromIndex = 0
    @State private var dragHeight: CGFloat = 0
    @State private var targetOffset = 0
    
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
        VStack(spacing: 0) {
            if showingAddField {
                addField
                breakLine
            }

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, task in
                        taskRow(task, index: index, isFocus: index == 0)

                        if index < rows.count - 1 {
                            breakLine
                        }
                    }
                }
                .coordinateSpace(name: "taskList")
                .onPreferenceChange(RowFramePreferenceKey.self) { rowFrames = $0 }
            }
        }
        .onAppear { syncRows() }
        .onChange(of: pendingTasks.map(\.id)) { _, _ in
            if draggingID == nil { syncRows() }
        }
        .sensoryFeedback(.selection, trigger: targetOffset)
        .sensoryFeedback(.impact(weight: .light), trigger: draggingID)
    }

    private var breakLine: some View {
        Rectangle()
            .fill(Color.intentioButton.opacity(0.12))
            .frame(height: 1)
            .padding(.leading, 22)
    }

    private var addField: some View {
        HStack(spacing: 12) {
            TextField("New intention", text: $newTaskText, axis: .vertical)
                .font(.system(.body, design: .serif))
                .focused($addFieldFocused)
                .onSubmit { addTask() }

            Button(action: addTask) {
                Image(systemName: "checkmark")
                    .foregroundStyle(Color.intentioButton)
            }
            .disabled(newTaskText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 4)
    }

    private func taskRow(_ task: TaskItem, index: Int, isFocus: Bool) -> some View {
        let isDragging = task.id == draggingID

        return HStack(spacing: 12) {
            // Subtle "focusing now" cue: the top task gets a filled dot and
            // full-strength text; the rest sit quietly dimmed below it.
            Circle()
                .fill(isFocus ? Color.intentioButton : Color.clear)
                .frame(width: 6, height: 6)

            Text(task.text)
                .font(.system(.body, design: .serif))
                .fontWeight(isFocus ? .medium : .regular)
                .foregroundStyle(isFocus ? Color.primary : Color.primary.opacity(0.45))

            Spacer()

            Image(systemName: "line.3.horizontal")
                .font(.system(size: 13))
                .foregroundStyle(Color.intentioButton.opacity(0.25))
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
        .background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: RowFramePreferenceKey.self,
                    value: [task.id: geo.frame(in: .named("taskList"))]
                )
            }
        )
        .scaleEffect(isDragging ? 1.03 : 1)
        .shadow(color: isDragging ? Color.black.opacity(0.18) : .clear, radius: 10, y: 4)
        .opacity(isDragging ? 0.97 : 1)
        .offset(y: displayOffset(index: index, id: task.id))
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: targetOffset)
        .zIndex(isDragging ? 1 : 0)
        .onTapGesture { selectedTask = task }
        .highPriorityGesture(reorderGesture(for: task))
    }

    /// Vertical shift for a row mid-drag: the lifted row tracks the finger, and
    /// the rows it passes slide aside to open a gap at the drop position.
    private func displayOffset(index: Int, id: PersistentIdentifier) -> CGFloat {
        if id == draggingID { return dragTranslation }
        guard draggingID != nil else { return 0 }

        let landing = targetOffset > dragFromIndex ? targetOffset - 1 : targetOffset
        if landing > dragFromIndex, index > dragFromIndex, index <= landing { return -dragHeight }
        if landing < dragFromIndex, index >= landing, index < dragFromIndex { return dragHeight }
        return 0
    }

    private func reorderGesture(for task: TaskItem) -> some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .named("taskList"))
            .onChanged { value in
                beginDrag(task)
                dragTranslation = value.translation.height
                updateTarget(locationY: value.location.y)
            }
            .onEnded { _ in commitOrder() }
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
        
        let maxOrder = rows.map(\.order).max() ?? -1
        let task = TaskItem(text: trimmed, order: maxOrder + 1)
        modelContext.insert(task)

        newTaskText = ""
        addFieldFocused = true
    }

    private func syncRows() {
        rows = pendingTasks
    }

    private func beginDrag(_ task: TaskItem) {
        guard draggingID == nil, let from = rows.firstIndex(where: { $0.id == task.id }) else { return }
        draggingID = task.id
        dragFromIndex = from
        dragHeight = rowFrames[task.id]?.height ?? 56
        frozenFrames = rowFrames
        targetOffset = from
    }

    /// Maps the finger's y-position to an insertion offset (0...count) using the
    /// resting layout captured at drag-start. Crossing a row's midpoint — or
    /// dragging past the first/last row — shifts where the task will land.
    private func updateTarget(locationY y: CGFloat) {
        var offset = 0
        for index in rows.indices {
            guard let frame = frozenFrames[rows[index].id] else { continue }
            if y > frame.midY { offset = index + 1 }
        }
        offset = min(max(offset, 0), rows.count)
        if offset != targetOffset { targetOffset = offset }
    }

    private func commitOrder() {
        guard draggingID != nil else { return }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            rows.move(fromOffsets: IndexSet(integer: dragFromIndex), toOffset: targetOffset)
            draggingID = nil
            dragTranslation = 0
        }

        for (index, task) in rows.enumerated() {
            task.order = index
        }
        try? modelContext.save()

        frozenFrames = [:]
        targetOffset = 0
    }
}

private struct RowFramePreferenceKey: PreferenceKey {
    static let defaultValue: [PersistentIdentifier: CGRect] = [:]
    static func reduce(
        value: inout [PersistentIdentifier: CGRect],
        nextValue: () -> [PersistentIdentifier: CGRect]
    ) {
        value.merge(nextValue()) { $1 }
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
