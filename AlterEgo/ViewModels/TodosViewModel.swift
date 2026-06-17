import Foundation
import SwiftUI

@MainActor
final class TodosViewModel: ObservableObject {
    @Published var todos: [Todo] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let db = SupabaseService.shared

    var openTodos: [Todo] {
        todos.filter { $0.status != "done" }
    }

    var groupedByAssignee: [(name: String, todos: [Todo])] {
        let assignees: [(name: String, id: UUID)] = [
            ("Mom",   Config.momID),
            ("Dad",   Config.dadID),
            ("Nanny", Config.nannyID)
        ]
        var result: [(name: String, todos: [Todo])] = []

        // Show todos per assignee
        for assignee in assignees {
            let group = openTodos.filter { $0.assignedTo == assignee.id }
            if !group.isEmpty { result.append((assignee.name, group)) }
        }

        // Catch-all: unassigned or assigned to unknown user
        let knownIDs = Set(assignees.map { $0.id })
        let other = openTodos.filter {
            $0.assignedTo == nil || !knownIDs.contains($0.assignedTo!)
        }
        if !other.isEmpty { result.append(("Other", other)) }

        return result
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            todos = try await db.fetchTodos()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func markDone(_ todo: Todo) async {
        if let idx = todos.firstIndex(where: { $0.id == todo.id }) {
            todos[idx] = Todo(
                id: todo.id, title: todo.title, description: todo.description,
                assignedTo: todo.assignedTo, createdBy: todo.createdBy,
                priority: todo.priority, status: "done",
                dueDate: todo.dueDate, delegatedVia: todo.delegatedVia,
                source: todo.source, createdAt: todo.createdAt, completedAt: Date()
            )
        }
        do {
            try await db.updateTodoStatus(id: todo.id, status: "done")
        } catch {
            errorMessage = error.localizedDescription
            await load()
        }
    }

    func addTodo(title: String, assignedTo: UUID?, priority: String) async {
        do {
            let todo = try await db.addTodo(title: title, assignedTo: assignedTo, priority: priority)
            todos.insert(todo, at: 0)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
