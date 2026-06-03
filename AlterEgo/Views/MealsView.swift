import SwiftUI

struct MealsView: View {
    @StateObject private var vm = MealsViewModel()
    @State private var editingSlot: (date: Date, mealType: String)?
    @State private var editTitle = ""

    private let dayFormatter: DateFormatter = {
        let df = DateFormatter(); df.dateFormat = "EEE\nd"; return df
    }()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // Week navigation
                    HStack {
                        Button { vm.previousWeek() } label: {
                            Image(systemName: "chevron.left")
                                .font(.title3)
                        }
                        Spacer()
                        Text(vm.weekLabel)
                            .font(.subheadline.bold())
                        Spacer()
                        Button { vm.nextWeek() } label: {
                            Image(systemName: "chevron.right")
                                .font(.title3)
                        }
                    }
                    .padding(.horizontal)

                    if vm.isLoading {
                        ProgressView()
                    } else {
                        // Family meals grid
                        MealGridSection(
                            title: "Family Meals",
                            mealTypes: MealType.familyTypes,
                            dates: vm.weekDates,
                            vm: vm,
                            editingSlot: $editingSlot,
                            editTitle: $editTitle
                        )

                        // Baby meals grid
                        MealGridSection(
                            title: "Aurik's Meals",
                            mealTypes: MealType.babyTypes,
                            dates: vm.weekDates,
                            vm: vm,
                            editingSlot: $editingSlot,
                            editTitle: $editTitle,
                            accentColor: .orange
                        )

                        // Meal ideas
                        if !vm.ideas.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Meal Ideas")
                                    .font(.headline)
                                FlowLayout(items: vm.ideas, spacing: 8) { idea in
                                    Text(idea.title)
                                        .font(.caption)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Color(.systemGray6))
                                        .clipShape(Capsule())
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

// MARK: - Meal grid section (family or baby)
struct MealGridSection: View {
    let title: String
    let mealTypes: [MealType]
    let dates: [Date]
    @ObservedObject var vm: MealsViewModel
    @Binding var editingSlot: (date: Date, mealType: String)?
    @Binding var editTitle: String
    var accentColor: Color = .accentColor

    @State private var editText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundStyle(accentColor)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // Header row (days)
                    HStack(spacing: 4) {
                        Text("")
                            .frame(width: 60)
                        ForEach(dates, id: \.self) { date in
                            DayHeader(date: date)
                                .frame(width: 70)
                        }
                    }
                    .padding(.horizontal, 8)

                    // Meal rows
                    ForEach(mealTypes, id: \.rawValue) { mealType in
                        HStack(spacing: 4) {
                            Text(mealType.label)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 60, alignment: .leading)
                                .lineLimit(2)

                            ForEach(dates, id: \.self) { date in
                                let currentTitle = vm.title(for: date, mealType: mealType.rawValue)
                                let isEditing = editingSlot?.date == date && editingSlot?.mealType == mealType.rawValue

                                MealCell(
                                    title: currentTitle,
                                    isToday: Calendar.current.isDateInToday(date),
                                    isEditing: isEditing,
                                    editText: $editText
                                ) {
                                    // on tap: start editing
                                    editText = currentTitle ?? ""
                                    editingSlot = (date: date, mealType: mealType.rawValue)
                                } onSave: {
                                    let slot = (date: date, mealType: mealType.rawValue)
                                    editingSlot = nil
                                    Task { await vm.setMeal(date: slot.date, mealType: slot.mealType, title: editText) }
                                }
                                .frame(width: 70)
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

struct DayHeader: View {
    let date: Date
    private let df: DateFormatter = { let f = DateFormatter(); f.dateFormat = "EEE"; return f }()

    var body: some View {
        VStack(spacing: 2) {
            Text(df.string(from: date))
                .font(.caption2.bold())
                .foregroundStyle(Calendar.current.isDateInToday(date) ? .accentColor : .secondary)
            Text("\(Calendar.current.component(.day, from: date))")
                .font(.subheadline.bold())
                .foregroundStyle(Calendar.current.isDateInToday(date) ? .accentColor : .primary)
        }
        .padding(.bottom, 4)
    }
}

struct MealCell: View {
    let title: String?
    let isToday: Bool
    let isEditing: Bool
    @Binding var editText: String
    let onTap: () -> Void
    let onSave: () -> Void

    var body: some View {
        Group {
            if isEditing {
                TextField("Meal...", text: $editText)
                    .font(.caption2)
                    .padding(6)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .onSubmit { onSave() }
                    .submitLabel(.done)
            } else {
                Button(action: onTap) {
                    Text(title.map { $0.isEmpty ? "—" : $0 } ?? "—")
                        .font(.caption2)
                        .foregroundStyle(title?.isEmpty == false ? .primary : .secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(6)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(isToday ? Color.accentColor.opacity(0.1) : Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Simple flow layout for meal ideas
struct FlowLayout<T: Identifiable, Content: View>: View {
    let items: [T]
    let spacing: CGFloat
    @ViewBuilder let content: (T) -> Content

    var body: some View {
        // Simplified wrapping layout using lazy grid
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 80, maximum: 140))],
            alignment: .leading,
            spacing: spacing
        ) {
            ForEach(items) { item in
                content(item)
            }
        }
    }
}
