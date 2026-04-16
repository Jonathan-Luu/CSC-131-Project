import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var store: NutritionStore
    @State private var path: [Date] = []
    @State private var displayedMonth: Date = Date().startOfMonth
    @State private var selectedDay: Date = Date().startOfDay
    @State private var showMonthPicker: Bool = false

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 12) {
                CalendarView(
                    displayedMonth: $displayedMonth,
                    selectedDate: selectedDay,
                    entryDays: entryDaysInLog,
                    minMonth: minMonth,
                    maxMonth: maxMonth,
                    today: today,
                    onTapMonthTitle: { showMonthPicker = true }
                ) { day in
                    selectedDay = day
                    path.append(day)
                }

                NavigationLink {
                    AllEntriesHistoryView()
                } label: {
                    Label("Show all entries", systemImage: "list.bullet")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .padding(.horizontal)

                if store.entries.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("No foods added yet.")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                } else {
                    Text("Tap a day to see foods logged on that date.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                }
                Spacer(minLength: 0)
            }
            .navigationTitle("Food History")
            .navigationDestination(for: Date.self) { day in
                DayHistoryView(day: day)
            }
            .onAppear {
                selectedDay = today
                displayedMonth = today.startOfMonth
            }
            .sheet(isPresented: $showMonthPicker) {
                MonthPickerSheet(
                    minMonth: minMonth,
                    maxMonth: maxMonth,
                    initialMonth: displayedMonth
                ) { newMonth in
                    displayedMonth = newMonth.startOfMonth
                }
            }
        }
    }

    private var entryDaysInLog: Set<Date> {
        Set(store.entries.map { $0.date.startOfDay })
    }

    private var today: Date { Date().startOfDay }

    private var minMonth: Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 1))?.startOfMonth ?? today.startOfMonth
    }

    /// Future months are unavailable entirely.
    private var maxMonth: Date {
        today.startOfMonth
    }
}

private struct MonthPickerSheet: View {
    let minMonth: Date
    let maxMonth: Date
    let initialMonth: Date
    var onSelectMonth: (Date) -> Void

    @Environment(\.dismiss) private var dismiss

    private let cal = Calendar.current

    @State private var selectedIndex: Int = 0

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Month", selection: $selectedIndex) {
                        ForEach(monthOptions.indices, id: \.self) { idx in
                            Text(monthLabel(monthOptions[idx]))
                                .tag(idx)
                        }
                    }
                    .pickerStyle(.wheel)
                }
            }
            .navigationTitle("Select month")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Go") {
                        if monthOptions.indices.contains(selectedIndex) {
                            onSelectMonth(monthOptions[selectedIndex])
                        }
                        dismiss()
                    }
                }
            }
            .onAppear {
                let initial = clampMonth(initialMonth.startOfMonth)
                selectedIndex = monthOptions.firstIndex(where: { $0.startOfMonth == initial }) ?? 0
            }
        }
        .presentationDetents([.medium])
    }

    private var monthOptions: [Date] {
        var out: [Date] = []
        var cur = clampMonth(minMonth.startOfMonth)
        let end = clampMonth(maxMonth.startOfMonth)
        while cur <= end {
            out.append(cur)
            cur = cur.addingMonths(1).startOfMonth
        }
        return out
    }

    private func monthLabel(_ d: Date) -> String {
        let f = DateFormatter()
        f.calendar = cal
        f.locale = .current
        f.dateFormat = "LLLL yyyy"
        return f.string(from: d)
    }

    private func clampMonth(_ d: Date) -> Date {
        let s = d.startOfMonth
        if s < minMonth.startOfMonth { return minMonth.startOfMonth }
        if s > maxMonth.startOfMonth { return maxMonth.startOfMonth }
        return s
    }
}
