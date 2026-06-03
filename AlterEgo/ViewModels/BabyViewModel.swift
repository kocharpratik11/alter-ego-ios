import Foundation
import SwiftUI

@MainActor
final class BabyViewModel: ObservableObject {
    @Published var logs: [BabyLog] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedFilter: String? = nil  // nil = all

    private let db = SupabaseService.shared

    let logTypes = ["feed", "sleep", "solid", "diaper"]

    var filteredLogs: [BabyLog] {
        guard let f = selectedFilter else { return logs }
        return logs.filter { $0.logType == f }
    }

    var logsByDay: [(day: String, logs: [BabyLog])] {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let grouped = Dictionary(grouping: filteredLogs) { log -> String in
            guard let d = log.startedAt else { return "Unknown" }
            return df.string(from: d)
        }
        return grouped.keys.sorted(by: >).map { day in
            (day: day, logs: grouped[day]!.sorted { ($0.startedAt ?? .distantPast) > ($1.startedAt ?? .distantPast) })
        }
    }

    // Sleep durations per day for bar chart (last 7 days)
    var sleepByDay: [(day: String, minutes: Int)] {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let sleepLogs = logs.filter { $0.logType == "sleep" }
        let grouped = Dictionary(grouping: sleepLogs) { log -> String in
            guard let d = log.startedAt else { return "Unknown" }
            return df.string(from: d)
        }
        let cal = Calendar.current
        return (0..<7).reversed().map { offset in
            let date = cal.date(byAdding: .day, value: -offset, to: Date())!
            let key = df.string(from: date)
            let total = grouped[key]?.compactMap { $0.durationMinutes }.reduce(0, +) ?? 0
            return (day: key, minutes: total)
        }
    }

    var todayFeedCount: Int {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let today = df.string(from: Date())
        return logs.filter { $0.logType == "feed" && $0.startedAt.map { df.string(from: $0) == today } == true }.count
    }

    var lastSleepSummary: String {
        guard let last = logs.first(where: { $0.logType == "sleep" }) else { return "No sleep logged" }
        if let mins = last.durationMinutes {
            let h = mins / 60; let m = mins % 60
            return h > 0 ? "\(h)h \(m)m" : "\(m)m"
        }
        return last.displayTime
    }

    func load(days: Int = 7) async {
        isLoading = true
        errorMessage = nil
        do {
            logs = try await db.fetchBabyLogs(days: days)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func addLog(logType: String, durationMinutes: Int?, amount: String?, value: String?, notes: String?) async {
        do {
            let log = try await db.addBabyLog(
                logType: logType,
                durationMinutes: durationMinutes,
                amount: amount,
                value: value,
                notes: notes
            )
            logs.insert(log, at: 0)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
