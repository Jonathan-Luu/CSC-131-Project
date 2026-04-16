import SwiftUI

struct CalendarView: View {
    @Binding var displayedMonth: Date
    var selectedDate: Date?
    var entryDays: Set<Date>
    var minMonth: Date
    var maxMonth: Date
    var today: Date
    var onTapMonthTitle: () -> Void
    var onSelectDay: (Date) -> Void

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(minimum: 20), spacing: 8), count: 7)

    var body: some View {
        VStack(spacing: 12) {
            header

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(0..<leadingBlankDays, id: \.self) { _ in
                    Color.clear
                        .frame(height: 36)
                }

                ForEach(daysInMonth, id: \.self) { day in
                    dayCell(for: day)
                }
            }
            .padding(.horizontal, 8)
        }
        .padding(.vertical, 8)
    }

    private var header: some View {
        HStack {
            Button {
                displayedMonth = clampMonth(displayedMonth.addingMonths(-1))
            } label: {
                Image(systemName: "chevron.left")
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 36, height: 36)
            }
            .disabled(!canGoPreviousMonth)
            .accessibilityLabel("Previous month")

            Spacer()

            Button {
                onTapMonthTitle()
            } label: {
                HStack(spacing: 6) {
                    Text(monthTitle(displayedMonth))
                        .font(.headline)
                    Image(systemName: "chevron.down")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.thinMaterial, in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Select month")

            Spacer()

            Button {
                displayedMonth = clampMonth(displayedMonth.addingMonths(1))
            } label: {
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 36, height: 36)
            }
            .disabled(!canGoNextMonth)
            .accessibilityLabel("Next month")
        }
        .padding(.horizontal, 8)
    }

    private func dayCell(for date: Date) -> some View {
        let isSelected = selectedDate.map { $0.isSameDay(as: date) } ?? false
        let hasEntries = entryDays.contains(date.startOfDay)

        let isInFuture = date.startOfDay > today.startOfDay
        let isDisabled = isInFuture

        return Button {
            onSelectDay(date.startOfDay)
        } label: {
            ZStack {
                if isSelected {
                    Circle()
                        .fill(Color.accentColor.opacity(0.18))
                        .frame(width: 36, height: 36)
                }

                Text("\(calendar.component(.day, from: date))")
                    .font(.subheadline)
                    .foregroundStyle(isDisabled ? .tertiary : .primary)
                    .frame(width: 36, height: 36)

                if hasEntries {
                    Circle()
                        .fill(isSelected ? Color.accentColor : Color.primary.opacity(0.65))
                        .frame(width: 5, height: 5)
                        .offset(y: 14)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityLabel(accessibilityLabel(for: date, hasEntries: hasEntries, isDisabled: isDisabled))
    }

    private var weekdaySymbols: [String] {
        let syms = calendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(syms[first...] + syms[..<first])
    }

    private var monthStart: Date {
        clampMonth(displayedMonth.startOfMonth)
    }

    private var daysInMonth: [Date] {
        guard let range = calendar.range(of: .day, in: .month, for: monthStart) else { return [] }
        return range.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: monthStart)
        }
    }

    private var leadingBlankDays: Int {
        let weekday = calendar.component(.weekday, from: monthStart)
        return (weekday - calendar.firstWeekday + 7) % 7
    }

    private var canGoPreviousMonth: Bool {
        monthStart > minMonth.startOfMonth
    }

    private var canGoNextMonth: Bool {
        monthStart < maxMonth.startOfMonth
    }

    private func clampMonth(_ d: Date) -> Date {
        let s = d.startOfMonth
        if s < minMonth.startOfMonth { return minMonth.startOfMonth }
        if s > maxMonth.startOfMonth { return maxMonth.startOfMonth }
        return s
    }

    private func monthTitle(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = calendar
        f.locale = .current
        f.dateFormat = "LLLL yyyy"
        return f.string(from: date)
    }

    private func accessibilityLabel(for date: Date, hasEntries: Bool, isDisabled: Bool) -> String {
        let f = DateFormatter()
        f.calendar = calendar
        f.locale = .current
        f.dateStyle = .full
        let base = f.string(from: date)
        if isDisabled { return "\(base), future date" }
        return hasEntries ? "\(base), has entries" : base
    }
}

