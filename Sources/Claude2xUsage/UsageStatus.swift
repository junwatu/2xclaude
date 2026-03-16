import Foundation

struct UsageStatus {
    enum Status: String {
        case twoX = "2x"
        case normal = "normal"
    }

    let status: Status
    let reason: String
    let ptTime: String
    let nextChangeInMinutes: Int

    var menuBarText: String {
        switch status {
        case .twoX:  return "🟢 2× Claude"
        case .normal: return "⚪ Claude peak"
        }
    }

    static func current() -> UsageStatus {
        let pt = TimeZone(identifier: "America/Los_Angeles")!
        let now = Date()

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = pt

        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .weekday], from: now)
        let hour = components.hour!
        let weekday = components.weekday! // 1=Sun, 7=Sat

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.timeZone = pt
        let ptTimeString = formatter.string(from: now)

        let isWeekend = (weekday == 1 || weekday == 7)

        if isWeekend {
            // 2x all day on weekends. Next change: Monday 05:00 PT
            let daysUntilMonday: Int
            if weekday == 7 { // Saturday
                daysUntilMonday = 2
            } else { // Sunday
                daysUntilMonday = 1
            }
            var nextMonday = calendar.date(byAdding: .day, value: daysUntilMonday, to: now)!
            nextMonday = calendar.date(bySettingHour: 5, minute: 0, second: 0, of: nextMonday)!
            let minutesUntil = Int(nextMonday.timeIntervalSince(now) / 60)

            return UsageStatus(
                status: .twoX,
                reason: "Weekend — 2× usage is active all day",
                ptTime: ptTimeString,
                nextChangeInMinutes: max(minutesUntil, 0)
            )
        }

        // Weekday: peak is 05:00–10:59 PT
        let isPeak = (hour >= 5 && hour < 11)

        if isPeak {
            // Next change: today at 11:00 PT
            var next = calendar.date(bySettingHour: 11, minute: 0, second: 0, of: now)!
            if next <= now {
                next = calendar.date(byAdding: .day, value: 1, to: next)!
            }
            let minutesUntil = Int(next.timeIntervalSince(now) / 60)

            return UsageStatus(
                status: .normal,
                reason: "Weekday peak hours (05:00–11:00 PT)",
                ptTime: ptTimeString,
                nextChangeInMinutes: max(minutesUntil, 0)
            )
        } else {
            // 2x active. Next change: next weekday 05:00 PT
            let nextChange: Date
            if hour < 5 {
                // Before 05:00 today
                nextChange = calendar.date(bySettingHour: 5, minute: 0, second: 0, of: now)!
            } else {
                // After 11:00, next change is tomorrow 05:00 (if weekday) or Monday 05:00
                var tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
                let tomorrowWeekday = calendar.component(.weekday, from: tomorrow)
                // If tomorrow is Saturday (7), skip to Monday (+3 days from today)
                if tomorrowWeekday == 7 {
                    tomorrow = calendar.date(byAdding: .day, value: 3, to: now)!
                } else if tomorrowWeekday == 1 { // Sunday
                    tomorrow = calendar.date(byAdding: .day, value: 2, to: now)!
                }
                nextChange = calendar.date(bySettingHour: 5, minute: 0, second: 0, of: tomorrow)!
            }
            let minutesUntil = Int(nextChange.timeIntervalSince(now) / 60)

            return UsageStatus(
                status: .twoX,
                reason: "Outside weekday peak hours — 2× usage active",
                ptTime: ptTimeString,
                nextChangeInMinutes: max(minutesUntil, 0)
            )
        }
    }
}
