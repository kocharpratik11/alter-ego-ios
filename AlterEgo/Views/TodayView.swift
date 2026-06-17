import SwiftUI

struct TodayView: View {
    @Binding var selectedTab: Int
    @StateObject private var groceryVM = GroceryViewModel()
    @StateObject private var babyVM   = BabyViewModel()
    @StateObject private var todosVM  = TodosViewModel()
    @StateObject private var mealsVM  = MealsViewModel()

    private var todayStr: String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return df.string(from: Date())
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // Greeting
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(greeting), \(Config.currentUserName)")
                            .font(.title2.bold())
                        Text(Date().formatted(date: .long, time: .omitted))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)

                    // Quick stats — tap to jump to the relevant tab
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        StatCard(
                            icon: "cart.fill",
                            label: "Need to buy",
                            value: "\(groceryVM.items.filter { $0.status == "needed" }.count) items",
                            color: .blue
                        )
                        .onTapGesture { selectedTab = 1 }

                        StatCard(
                            icon: "moon.fill",
                            label: "Last sleep",
                            value: babyVM.lastSleepSummary,
                            color: .indigo
                        )
                        .onTapGesture { selectedTab = 2 }

                        StatCard(
                            icon: "drop.fill",
                            label: "Today's feeds",
                            value: "\(babyVM.todayFeedCount) feeds",
                            color: .teal
                        )
                        .onTapGesture { selectedTab = 2 }

                        StatCard(
                            icon: "checklist",
                            label: "Open todos",
                            value: "\(todosVM.openTodos.count) tasks",
                            color: .orange
                        )
                        .onTapGesture { selectedTab = 4 }
                    }
                    .padding(.horizontal)

                    // Today's Meals — Mom
                    SectionCard(title: "Mom's Meals Today") {
                        ForEach(MealType.momTypes, id: \.rawValue) { mealType in
                            HStack {
                                Text(mealType.label)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                let title = mealsVM.title(for: Date(), mealType: mealType.rawValue)
                                Text(title?.isEmpty == false ? title! : "—")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(title?.isEmpty == false ? .primary : .secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .onTapGesture { selectedTab = 3 }

                    // Today's Meals — Dad
                    SectionCard(title: "Dad's Meals Today") {
                        ForEach(MealType.dadTypes, id: \.rawValue) { mealType in
                            HStack {
                                Text(mealType.label)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                let title = mealsVM.title(for: Date(), mealType: mealType.rawValue)
                                Text(title?.isEmpty == false ? title! : "—")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(title?.isEmpty == false ? .primary : .secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .onTapGesture { selectedTab = 3 }

                    // Today's Todos
                    if !todosVM.openTodos.isEmpty {
                        SectionCard(title: "Today's Tasks") {
                            ForEach(todosVM.openTodos.prefix(5)) { todo in
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: "circle")
                                        .foregroundStyle(.secondary)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(todo.title)
                                            .font(.subheadline)
                                        Text(todo.assigneeName)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    PriorityBadge(priority: todo.priority)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }

                    // Baby today
                    let todayBabyLogs = babyVM.logs.filter {
                        guard let d = $0.startedAt else { return false }
                        return Calendar.current.isDateInToday(d)
                    }
                    if !todayBabyLogs.isEmpty {
                        SectionCard(title: "Aurik today") {
                            ForEach(todayBabyLogs.prefix(5)) { log in
                                HStack {
                                    Image(systemName: log.logTypeIcon)
                                        .foregroundStyle(.secondary)
                                        .frame(width: 20)
                                    Text(log.value ?? log.amount ?? log.logType.capitalized)
                                        .font(.subheadline)
                                    Spacer()
                                    Text(log.displayTime)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 3)
                            }
                        }
                    }
                }
                .padding(.bottom, 20)
            }
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                await loadAll()
            }
            .task {
                await loadAll()
            }
        }
    }

    private func loadAll() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.groceryVM.load() }
            group.addTask { await self.babyVM.load(days: 1) }
            group.addTask { await self.todosVM.load() }
            group.addTask { await self.mealsVM.load() }
        }
    }
}

// MARK: - Reusable components

struct StatCard: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.title3)
            Text(value)
                .font(.headline)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }
}

struct SectionCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            content()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        .padding(.horizontal)
    }
}

struct EmptyStateView: View {
    let title: String
    let systemImage: String
    let description: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct PriorityBadge: View {
    let priority: String

    var color: Color {
        switch priority {
        case "high":   return .red
        case "medium": return .orange
        case "low":    return .green
        default:       return .gray
        }
    }

    var body: some View {
        Text(priority.capitalized)
            .font(.caption2.bold())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}
