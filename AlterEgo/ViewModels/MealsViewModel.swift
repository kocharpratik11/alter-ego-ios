import Foundation
import SwiftUI

@MainActor
final class MealsViewModel: ObservableObject {
    @Published var plan: [String: [String: String]] = [:]  // [date: [mealType: title]]
    @Published var ideas: [MealIdea] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    var weekStart: Date = MealsViewModel.currentMonday() {
        didSet { Task { await load() } }
    }

    private let db = SupabaseService.shared

    static func currentMonday() -> Date {
        var cal = Calendar.current
        cal.firstWeekday = 2
        let today = cal.startOfDay(for: Date())
        let weekday = cal.component(.weekday, from: today)
        let daysToMonday = (weekday + 5) % 7
        return cal.date(byAdding: .day, value: -daysToMonday, to: today)!
    }

    var weekDates: [Date] {
        (0..<7).map { Calendar.current.date(byAdding: .day, value: $0, to: weekStart)! }
    }

    var weekLabel: String {
        let df = DateFormatter()
        df.dateFormat = "MMM d"
        let end = weekDates.last!
        return "\(df.string(from: weekStart)) – \(df.string(from: end))"
    }

    func title(for date: Date, mealType: String) -> String? {
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        return plan[df.string(from: date)]?[mealType]
    }

    func load() async {
        let df2 = DateFormatter(); df2.dateFormat = "yyyy-MM-dd"
        print("🍽 load() called — weekStart: \(df2.string(from: weekStart))")
        isLoading = true
        errorMessage = nil
        do {
            let meals = try await db.fetchMealPlan(weekStart: weekStart)
            print("🍽 fetched \(meals.count) meals")
            for m in meals { print("  \(m.dateString) \(m.mealType): \(m.title ?? "(empty)")") }
            var newPlan: [String: [String: String]] = [:]
            for meal in meals {
                if newPlan[meal.dateString] == nil { newPlan[meal.dateString] = [:] }
                newPlan[meal.dateString]?[meal.mealType] = meal.title ?? ""
            }
            plan = newPlan
        } catch {
            print("🍽 meal plan error: \(error)")
            errorMessage = error.localizedDescription
        }
        // Fetch ideas independently so a missing table doesn't affect the meal grid
        do {
            ideas = try await db.fetchMealIdeas()
            print("🍽 fetched \(ideas.count) ideas")
        } catch {
            print("🍽 ideas error (ignored): \(error)")
            ideas = []
        }
        isLoading = false
    }

    func setMeal(date: Date, mealType: String, title: String) async {
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        let key = df.string(from: date)
        print("🍽 setMeal: \(key) \(mealType) = '\(title)'")
        if plan[key] == nil { plan[key] = [:] }
        plan[key]?[mealType] = title
        print("🍽 optimistic update applied")
        do {
            try await db.upsertMealSlot(date: date, mealType: mealType, title: title)
            print("🍽 upsert succeeded")
        } catch {
            print("🍽 upsert FAILED: \(error)")
            errorMessage = error.localizedDescription
            await load()
        }
    }

    func previousWeek() {
        weekStart = Calendar.current.date(byAdding: .day, value: -7, to: weekStart)!
    }

    func nextWeek() {
        weekStart = Calendar.current.date(byAdding: .day, value: 7, to: weekStart)!
    }
}
