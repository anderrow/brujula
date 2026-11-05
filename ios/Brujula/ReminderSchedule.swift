import Foundation

struct ReminderSchedule: Codable, Equatable {
    enum Frequency: String, CaseIterable, Identifiable, Codable {
        case daily, weekly, monthly
        var id: String { rawValue }
        var title: String {
            switch self {
            case .daily: return localized("Daily")
            case .weekly: return localized("Weekly")
            case .monthly: return localized("Monthly")
            }
        }
    }

    var enabled = false
    var frequency = Frequency.daily
    var hour = 20
    var minute = 0
    var weekday = 2
    var monthDay = 1

    var valid: Bool {
        (0...23).contains(hour) && (0...59).contains(minute) &&
        (1...7).contains(weekday) && (1...31).contains(monthDay)
    }

    func repeatingComponents() -> DateComponents? {
        var match = DateComponents(hour: hour, minute: minute)
        switch frequency {
        case .daily: break
        case .weekly: match.weekday = weekday
        case .monthly:
            guard monthDay <= 28 else { return nil }
            match.day = monthDay
        }
        return match
    }

    func upcomingMonthDates(after now: Date, calendar: Calendar, count: Int = 48) -> [Date] {
        guard valid, count > 0, let start = calendar.dateInterval(of: .month, for: now)?.start else { return [] }
        return (0...count).compactMap { offset -> Date? in
            guard let month = calendar.date(byAdding: .month, value: offset, to: start),
                  let days = calendar.range(of: .day, in: .month, for: month),
                  let day = calendar.date(byAdding: .day, value: min(monthDay, days.count) - 1, to: month),
                  let date = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day,
                                           matchingPolicy: .nextTime, repeatedTimePolicy: .first),
                  calendar.isDate(day, inSameDayAs: date), date > now else { return nil }
            return date
        }.prefix(count).map { $0 }
    }
}
