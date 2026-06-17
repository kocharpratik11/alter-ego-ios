import SwiftUI

struct MealsView: View {
    @StateObject private var vm = MealsViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // Week navigation
                    HStack {
                        Button { vm.previousWeek() } label: {
                            Image(systemName: "chevron.left").font(.title3)
                        }
                        Spacer()
                        Text(vm.weekLabel).font(.subheadline.bold())
                        Spacer()
                        Button { vm.nextWeek() } label: {
                            Image(systemName: "chevron.right").font(.title3)
                        }
                    }
                    .padding(.horizontal)

                    if vm.isLoading {
                        ProgressView()
                    } else {
                        MealGridSection(
                            title: "Mom's Meals",
                            mealTypes: MealType.momTypes,
                            dates: vm.weekDates,
                            vm: vm,
                            accentColor: .pink
                        )

                        MealGridSection(
                            title: "Dad's Meals",
                            mealTypes: MealType.dadTypes,
                            dates: vm.weekDates,
                            vm: vm,
                            accentColor: .blue
                        )

                        MealGridSection(
                            title: "Aurik's Meals",
                            mealTypes: MealType.babyTypes,
                            dates: vm.weekDates,
                            vm: vm,
                            accentColor: .orange
                        )

                        // Meal ideas — draggable chips
                        MealIdeasSection(vm: vm)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Meals")
            .refreshable { await vm.load() }
            .task { await vm.load() }
            .alert("Error", isPresented: .constant(vm.errorMessage != nil)) {
                Button("OK") { vm.errorMessage = nil }
            } message: {
                Text(vm.errorMessage ?? "")
            }
        }
    }
}

// MARK: - Meal ideas section

struct MealIdeasSection: View {
    @ObservedObject var vm: MealsViewModel
    @State private var showAdd  = false
    @State private var newIdea  = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Meal Ideas")
                    .font(.headline)
                Spacer()
                Button {
                    newIdea = ""
                    showAdd = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.tint)
                }
            }

            if vm.ideas.isEmpty {
                Text("No ideas yet — tap + to add one")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Drag an idea onto a meal slot, or tap a slot to edit")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 80, maximum: 160))],
                    alignment: .leading,
                    spacing: 8
                ) {
                    ForEach(vm.ideas) { idea in
                        Text(idea.title)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(.systemGray6))
                            .clipShape(Capsule())
                            .draggable(idea.title)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        .padding(.horizontal)
        .alert("New Meal Idea", isPresented: $showAdd) {
            TextField("e.g. Chicken Biryani", text: $newIdea)
            Button("Add") {
                let title = newIdea.trimmingCharacters(in: .whitespaces)
                guard !title.isEmpty else { return }
                Task { await vm.addIdea(title: title) }
            }
            Button("Cancel", role: .cancel) { }
        }
    }
}

// MARK: - Meal grid section

struct MealGridSection: View {
    let title: String
    let mealTypes: [MealType]
    let dates: [Date]
    @ObservedObject var vm: MealsViewModel
    var accentColor: Color = .accentColor

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundStyle(accentColor)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {

                    // Day headers
                    HStack(spacing: 4) {
                        Spacer().frame(width: 64)
                        ForEach(dates, id: \.self) { date in
                            DayHeader(date: date)
                                .frame(width: 72)
                        }
                    }
                    .padding(.horizontal, 8)

                    // Meal rows
                    ForEach(mealTypes, id: \.rawValue) { mealType in
                        HStack(spacing: 4) {
                            Text(mealType.label)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 64, alignment: .leading)
                                .lineLimit(2)

                            ForEach(dates, id: \.self) { date in
                                DroppableMealCell(
                                    date: date,
                                    mealType: mealType,
                                    vm: vm
                                )
                                .frame(width: 72)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                    }
                }
            }
        }
        .padding(.vertical, 12)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        .padding(.horizontal)
    }
}

// MARK: - Drop-capable meal cell

struct DroppableMealCell: View {
    let date: Date
    let mealType: MealType
    @ObservedObject var vm: MealsViewModel

    @State private var showEdit   = false
    @State private var editText   = ""
    @State private var isTargeted = false

    private let df: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()

    private var currentTitle: String? {
        vm.title(for: date, mealType: mealType.rawValue)
    }

    private var dragPayload: String {
        "SLOT:\(df.string(from: date)):\(mealType.rawValue):\(currentTitle ?? "")"
    }

    var body: some View {
        Button {
            editText = currentTitle ?? ""
            showEdit = true
        } label: {
            Text(currentTitle.map { $0.isEmpty ? "—" : $0 } ?? "—")
                .font(.caption2)
                .foregroundStyle(currentTitle?.isEmpty == false ? .primary : .secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(6)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(
                    isTargeted
                        ? Color.accentColor.opacity(0.2)
                        : Calendar.current.isDateInToday(date)
                            ? Color.accentColor.opacity(0.1)
                            : Color(.systemGray6)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isTargeted ? Color.accentColor : Color.clear, lineWidth: 2)
                )
        }
        .buttonStyle(.plain)
        .draggable(dragPayload)
        .dropDestination(for: String.self) { items, _ in
            guard let payload = items.first, !payload.isEmpty else { return false }
            Task { await handleDrop(payload: payload) }
            return true
        } isTargeted: { isTargeted = $0 }
        .alert("Edit Meal", isPresented: $showEdit) {
            TextField("Meal name", text: $editText)
            Button("Save") {
                let title = editText.trimmingCharacters(in: .whitespaces)
                Task { await vm.setMeal(date: date, mealType: mealType.rawValue, title: title) }
            }
            Button("Clear", role: .destructive) {
                Task { await vm.setMeal(date: date, mealType: mealType.rawValue, title: "") }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("\(mealType.label) · \(df.string(from: date))")
        }
    }

    private func handleDrop(payload: String) async {
        if payload.hasPrefix("SLOT:") {
            let parts = payload.dropFirst("SLOT:".count)
                .split(separator: ":", maxSplits: 2, omittingEmptySubsequences: false)
                .map(String.init)
            guard parts.count == 3 else { return }
            let srcDateStr  = parts[0]
            let srcMealType = parts[1]
            let srcTitle    = parts[2]
            let destTitle   = currentTitle ?? ""
            if let srcDate = df.date(from: srcDateStr) {
                await vm.setMeal(date: date,    mealType: mealType.rawValue, title: srcTitle)
                await vm.setMeal(date: srcDate, mealType: srcMealType,       title: destTitle)
            }
        } else {
            await vm.setMeal(date: date, mealType: mealType.rawValue, title: payload)
        }
    }
}

// MARK: - Day header

struct DayHeader: View {
    let date: Date
    private let dayFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "EEE"; return f
    }()

    var isToday: Bool { Calendar.current.isDateInToday(date) }

    var body: some View {
        VStack(spacing: 2) {
            Text(dayFmt.string(from: date))
                .font(.caption2.bold())
                .foregroundStyle(isToday ? Color.accentColor : Color.secondary)
            Text("\(Calendar.current.component(.day, from: date))")
                .font(.subheadline.bold())
                .foregroundStyle(isToday ? Color.accentColor : Color.primary)
        }
        .padding(.bottom, 4)
    }
}
