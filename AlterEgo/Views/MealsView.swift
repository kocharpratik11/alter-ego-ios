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
                            title: "Family Meals",
                            mealTypes: MealType.familyTypes,
                            dates: vm.weekDates,
                            vm: vm,
                            accentColor: .accentColor
                        )

                        MealGridSection(
                            title: "Aurik's Meals",
                            mealTypes: MealType.babyTypes,
                            dates: vm.weekDates,
                            vm: vm,
                            accentColor: .orange
                        )

                        // Meal ideas — draggable chips
                        if !vm.ideas.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Meal Ideas")
                                    .font(.headline)
                                Text("Drag an idea onto a meal slot, or tap a slot to type")
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
                                            .draggable(idea.title)      // ← native iOS drag
                                    }
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.background)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
                            .padding(.horizontal)
                        }
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

    @State private var isEditing = false
    @State private var editText  = ""
    @State private var isTargeted = false

    private var currentTitle: String? {
        vm.title(for: date, mealType: mealType.rawValue)
    }

    var body: some View {
        Group {
            if isEditing {
                TextField("Meal...", text: $editText)
                    .font(.caption2)
                    .padding(6)
                    .frame(minHeight: 48)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .onSubmit { save() }
                    .submitLabel(.done)
            } else {
                Button {
                    editText  = currentTitle ?? ""
                    isEditing = true
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
            }
        }
        // ← native iOS drop target: accepts dragged String (meal idea title)
        .dropDestination(for: String.self) { items, _ in
            guard let title = items.first, !title.isEmpty else { return false }
            Task { await vm.setMeal(date: date, mealType: mealType.rawValue, title: title) }
            return true
        } isTargeted: { targeted in
            isTargeted = targeted
        }
    }

    private func save() {
        isEditing = false
        let title = editText.trimmingCharacters(in: .whitespaces)
        Task { await vm.setMeal(date: date, mealType: mealType.rawValue, title: title) }
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
