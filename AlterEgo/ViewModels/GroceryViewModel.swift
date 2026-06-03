import Foundation
import SwiftUI

@MainActor
final class GroceryViewModel: ObservableObject {
    @Published var items: [GroceryItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedStore: String? = nil

    private let db = SupabaseService.shared

    var stores: [String] { GroceryItem.stores }

    var groupedItems: [(store: String, items: [GroceryItem])] {
        let filtered = selectedStore == nil ? items : items.filter { $0.store == selectedStore }
        let active = filtered.filter { $0.status != "purchased" }
        let dict = Dictionary(grouping: active, by: { $0.store ?? "Other" })
        return GroceryItem.stores
            .compactMap { store -> (store: String, items: [GroceryItem])? in
                guard let storeItems = dict[store], !storeItems.isEmpty else { return nil }
                return (store, storeItems)
            }
    }

    var purchasedItems: [GroceryItem] {
        items.filter { $0.status == "purchased" }
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            items = try await db.fetchGroceryItems()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func cycleStatus(_ item: GroceryItem) async {
        let newStatus = item.nextStatus
        if let idx = items.firstIndex(where: { $0.id == item.id }) {
            items[idx] = GroceryItem(
                id: item.id, name: item.name, store: item.store,
                status: newStatus, quantity: item.quantity,
                addedBy: item.addedBy, source: item.source,
                createdAt: item.createdAt, purchasedAt: item.purchasedAt
            )
        }
        do {
            try await db.updateGroceryStatus(id: item.id, status: newStatus)
        } catch {
            errorMessage = error.localizedDescription
            await load() // revert on error
        }
    }

    func delete(_ item: GroceryItem) async {
        items.removeAll { $0.id == item.id }
        do {
            try await db.deleteGroceryItem(id: item.id)
        } catch {
            errorMessage = error.localizedDescription
            await load()
        }
    }

    func addItem(name: String, store: String?, quantity: String?) async {
        do {
            let item = try await db.addGroceryItem(name: name, store: store, quantity: quantity)
            items.insert(item, at: 0)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
