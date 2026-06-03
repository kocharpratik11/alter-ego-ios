import SwiftUI
import Charts

struct BabyTrackerView: View {
    @StateObject private var vm = BabyViewModel()
    @State private var showAdd = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {

                    // Filter chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            FilterChip(label: "All", isSelected: vm.selectedFilter == nil) {
                                vm.selectedFilter = nil
                            }
                            ForEach(vm.logTypes, id: \.self) { type in
                                FilterChip(label: type.capitalized, isSelected: vm.selectedFilter == type) {
                                    vm.selectedFilter = vm.selectedFilter == type ? nil : type
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Sleep chart
                    if vm.selectedFilter == nil || vm.selectedFilter == "sleep" {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Sleep (last 7 days)")
                                .font(.headline)
                                .padding(.horizontal)

                            Chart(vm.sleepByDay, id: \.day) { item in
                                BarMark(
                                    x: .value("Day", shortDay(item.day)),
                                    y: .value("Minutes", item.minutes)
                                )
                                .foregroundStyle(Color.indigo.gradient)
                                .cornerRadius(4)
                            }
                            .frame(height: 120)
                            .padding(.horizontal)
                            .chartYAxis {
                                AxisMarks { value in
                                    AxisValueLabel {
                                        if let mins = value.as(Int.self) {
                                            Text(minsToH(mins))
                                                .font(.caption2)
                                        }
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

                    // Logs grouped by day
                    if vm.isLoading && vm.logs.isEmpty {
                        ProgressView()
                    } else if vm.filteredLogs.isEmpty {
                        EmptyStateView(
                            title: "No Logs",
                            systemImage: "figure.and.child.holdinghands",
                            description: "Tap + to log a feed, sleep, or diaper"
                        )
                    } else {
                        ForEach(vm.logsByDay, id: \.day) { group in
                            VStack(alignment: .leading, spacing: 0) {
                                Text(dayLabel(group.day))
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal)
                                    .padding(.bottom, 6)

                                ForEach(group.logs) { log in
                                    BabyLogRow(log: log)
                                        .padding(.horizontal)
                                    if log.id != group.logs.last?.id {
                                        Divider().padding(.leading, 44)
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
                }
                .padding(.vertical)
            }
            .navigationTitle("Aurik")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showAdd = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .refreshable { await vm.load() }
            .task { await vm.load() }
            .sheet(isPresented: $showAdd) {
                AddBabyLogSheet(vm: vm, isPresented: $showAdd)
            }
            .alert("Error", isPresented: .constant(vm.errorMessage != nil)) {
                Button("OK") { vm.errorMessage = nil }
            } message: {
                Text(vm.errorMessage ?? "")
            }
        }
    }

    private func shortDay(_ dateStr: String) -> String {
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        guard let d = df.date(from: dateStr) else { return dateStr }
        let out = DateFormatter(); out.dateFormat = "EEE"
        return out.string(from: d)
    }

    private func minsToH(_ mins: Int) -> String {
        let h = mins / 60; let m = mins % 60
        if h == 0 { return "\(m)m" }
        return m == 0 ? "\(h)h" : "\(h)h\(m)m"
    }

    private func dayLabel(_ dateStr: String) -> String {
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        guard let d = df.date(from: dateStr) else { return dateStr }
        if Calendar.current.isDateInToday(d)     { return "Today" }
        if Calendar.current.isDateInYesterday(d) { return "Yesterday" }
        let out = DateFormatter(); out.dateFormat = "EEEE, MMM d"
        return out.string(from: d)
    }
}

struct BabyLogRow: View {
    let log: BabyLog

    var detail: String {
        var parts: [String] = []
        if let v = log.value  { parts.append(v) }
        if let a = log.amount { parts.append(a) }
        if let m = log.durationMinutes {
            let h = m / 60; let min = m % 60
            parts.append(h > 0 ? "\(h)h \(min)m" : "\(min)m")
        }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: log.logTypeIcon)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(log.logType.capitalized)
                    .font(.subheadline.bold())
                if !detail.isEmpty {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let notes = log.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(log.displayTime)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }
}

struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color(.systemGray6))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct AddBabyLogSheet: View {
    @ObservedObject var vm: BabyViewModel
    @Binding var isPresented: Bool
    @State private var logType = "feed"
    @State private var amount = ""
    @State private var value = ""
    @State private var durationStr = ""
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Log type") {
                    Picker("Type", selection: $logType) {
                        Text("Feed").tag("feed")
                        Text("Sleep").tag("sleep")
                        Text("Solid").tag("solid")
                        Text("Diaper").tag("diaper")
                        Text("Other").tag("other")
                    }
                    .pickerStyle(.segmented)
                }

                Section("Details") {
                    switch logType {
                    case "feed":
                        TextField("Amount (e.g. 4oz, left breast)", text: $amount)
                        TextField("Type (e.g. formula, breast milk)", text: $value)
                    case "sleep":
                        TextField("Duration in minutes (e.g. 45)", text: $durationStr)
                            .keyboardType(.numberPad)
                        TextField("Notes (e.g. deep sleep)", text: $notes)
                    case "solid":
                        TextField("What (e.g. pureed mango)", text: $value)
                        TextField("Amount (e.g. 3 spoonfuls)", text: $amount)
                    case "diaper":
                        TextField("Type (e.g. wet, dirty)", text: $value)
                    default:
                        TextField("Notes", text: $notes)
                    }
                }
            }
            .navigationTitle("Log for Aurik")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await vm.addLog(
                                logType: logType,
                                durationMinutes: Int(durationStr),
                                amount: amount.isEmpty ? nil : amount,
                                value: value.isEmpty ? nil : value,
                                notes: notes.isEmpty ? nil : notes
                            )
                            isPresented = false
                        }
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
