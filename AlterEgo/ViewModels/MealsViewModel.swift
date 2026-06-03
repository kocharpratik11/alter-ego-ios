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
        isLoading = true
        errorMessage = nil
        do {
            let meals = try await db.fetchMealPlan(weekStart: weekStart)
            var newPlan: [String: [String: String]] = [:]
            let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
            for meal in meals {
                let key = df.string(from: meal.date)
                if newPlan[key] == nil { newPlan[key] = [:] }
                newPlan[key]?[meal.mealType] = meal.title ?? ""
            }
            plan = newPlan
            ideas = try await db.fetchMealIdeas()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func setMeal(date: Date, mealType: String, title: String) async {
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        let key = df.string(from: date)
        if plan[key] == nil { plan[key] = [:] }
        plan[key]?[mealType] = title
        do {
            try await db.upsertMealSlot(date: date, mealType: mealType, title: title)
        } catch {
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
