import SwiftUI

struct GroceryView: View {
    @StateObject private var vm = GroceryViewModel()
    @State private var showAdd = false
    @State private var newName = ""
    @State private var newStore: String? = nil
    @State private var newQty = ""

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading && vm.items.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(vm.groupedItems, id: \.store) { group in
                            Section(header: Text(group.store).font(.subheadline.bold())) {
                                ForEach(group.items) { item in
                                    GroceryRow(item: item) {
                                        Task { await vm.cycleStatus(item) }
                                    }
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            Task { await vm.delete(item) }
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }

                        if !vm.purchasedItems.isEmpty {
                            Section(header: Text("Purchased").font(.subheadline.bold())) {
                                ForEach(vm.purchasedItems) { item in
                                    GroceryRow(item: item) {
                                        Task { await vm.cycleStatus(item) }
                                    }
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            Task { await vm.delete(item) }
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }

                        if vm.groupedItems.isEmpty && vm.purchasedItems.isEmpty {
                            ContentUnavailableView(
                                "No Items",
                                systemImage: "cart",
                                description: Text("Add items using the + button or Siri")
                            )
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Grocery")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showAdd = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .refreshable { await vm.load() }
            .task { await vm.load() }
            .alert("Error", isPresented: .constant(vm.errorMessage != nil)) {
                Button("OK") { vm.errorMessage = nil }
            } message: {
                Text(vm.errorMessage ?? "")
            }
            .sheet(isPresented: $showAdd) {
                AddGrocerySheet(vm: vm, isPresented: $showAdd)
            }
        }
    }
}

struct GroceryRow: View {
    let item: GroceryItem
    let onTap: () -> Void

    var statusColor: Color {
        switch item.status {
        case "needed":    return .primary
        case "in_cart":   return .blue
        case "purchased": return .secondary
        default:          return .primary
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onTap) {
                Image(systemName: item.statusIcon)
                    .foregroundStyle(item.status == "purchased" ? .green : .secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .strikethrough(item.status == "purchased")
                    .foregroundStyle(item.status == "purchased" ? .secondary : .primary)
                if let qty = item.quantity {
                    Text(qty)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .contentShape(Rectangle())
    }
}

struct AddGrocerySheet: View {
    @ObservedObject var vm: GroceryViewModel
    @Binding var isPresented: Bool
    @State private var name = ""
    @State private var store: String = "Other"
    @State private var quantity = ""
    @FocusState private var nameFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("Item") {
                    TextField("Name (e.g. Oat milk)", text: $name)
                        .focused($nameFocused)
                    TextField("Quantity (optional)", text: $quantity)
                }
                Section("Store") {
                    Picker("Store", selection: $store) {
                        ForEach(GroceryItem.stores, id: \.self) { s in
                            Text(s).tag(s)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .navigationTitle("Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        guard !name.isEmpty else { return }
                        Task {
                            await vm.addItem(
                                name: name,
                                store: store,
                                quantity: quantity.isEmpty ? nil : quantity
                            )
                            isPresented = false
                        }
                    }
                    .disabled(name.isEmpty)
                }
            }
            .onAppear { nameFocused = true }
        }
        .presentationDetents([.medium])
    }
}
