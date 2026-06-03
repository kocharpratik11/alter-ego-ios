import SwiftUI

struct TodosView: View {
    @StateObject private var vm = TodosViewModel()
    @State private var showAdd = false

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading && vm.todos.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if vm.openTodos.isEmpty {
                    ContentUnavailableView(
                        "All caught up!",
                        systemImage: "checkmark.seal.fill",
                        description: Text("No open tasks. Nice work.")
                    )
                } else {
                    List {
                        ForEach(vm.groupedByAssignee, id: \.id) { group in
                            Section(header: Text(group.name).font(.subheadline.bold())) {
                                ForEach(group.todos) { todo in
                                    TodoRow(todo: todo) {
                                        Task { await vm.markDone(todo) }
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Todos")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showAdd = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .refreshable { await vm.load() }
            .task { await vm.load() }
            .sheet(isPresented: $showAdd) {
                AddTodoSheet(vm: vm, isPresented: $showAdd)
            }
            .alert("Error", isPresented: .constant(vm.errorMessage != nil)) {
                Button("OK") { vm.errorMessage = nil }
            } message: {
                Text(vm.errorMessage ?? "")
            }
        }
    }
}

struct TodoRow: View {
    let todo: Todo
    let onComplete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: onComplete) {
                Image(systemName: todo.status == "done" ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(todo.status == "done" ? .green : .secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(todo.title)
                    .strikethrough(todo.status == "done")
                    .foregroundStyle(todo.status == "done" ? .secondary : .primary)

                if let desc = todo.description, !desc.isEmpty {
                    Text(desc)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let due = todo.dueDate {
                    Text("Due \(due.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Spacer()

            PriorityBadge(priority: todo.priority)
        }
        .padding(.vertical, 4)
    }
}

struct AddTodoSheet: View {
    @ObservedObject var vm: TodosViewModel
    @Binding var isPresented: Bool
    @State private var title = ""
    @State private var priority = "medium"
    @State private var assigneeID: UUID = Config.currentUserID
    @FocusState private var titleFocused: Bool

    private let assignees: [(name: String, id: UUID)] = [
        ("Mom",   Config.momID),
        ("Dad",   Config.dadID),
        ("Nanny", Config.nannyID)
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("What needs to be done?", text: $title)
                        .focused($titleFocused)
                }
                Section("Priority") {
                    Picker("Priority", selection: $priority) {
                        Text("Low").tag("low")
                        Text("Medium").tag("medium")
                        Text("High").tag("high")
                    }
                    .pickerStyle(.segmented)
                }
                Section("Assign to") {
                    Picker("Assignee", selection: $assigneeID) {
                        ForEach(assignees, id: \.id) { a in
                            Text(a.name).tag(a.id)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        guard !title.isEmpty else { return }
                        Task {
                            await vm.addTodo(title: title, assignedTo: assigneeID, priority: priority)
                            isPresented = false
                        }
                    }
                    .disabled(title.isEmpty)
                }
            }
            .onAppear { titleFocused = true }
        }
        .presentationDetents([.medium])
    }
}
