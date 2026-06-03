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

    var groupedByAssignee: [(name: String, id: UUID, todos: [Todo])] {
        let assignees: [(name: String, id: UUID)] = [
            ("Mom", Config.momID),
            ("Dad", Config.dadID),
            ("Nanny", Config.nannyID)
        ]
        return assignees.compactMap { assignee in
            let assigned = openTodos.filter { $0.assignedTo == assignee.id }
            let unassigned = assignee.id == Config.currentUserID
                ? openTodos.filter { $0.assignedTo == nil && $0.createdBy == Config.currentUserID }
                : []
            let all = assigned + unassigned
            guard !all.isEmpty else { return nil }
            return (name: assignee.name, id: assignee.id, todos: all)
        }
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
