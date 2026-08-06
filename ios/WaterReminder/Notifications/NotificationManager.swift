import Foundation
import UserNotifications

/// 本地通知调度。全部由系统触发，App 关闭时也会准时提醒，不需要服务端。
final class NotificationManager: @unchecked Sendable {
    static let shared = NotificationManager()

    enum Identifier {
        static let category = "WATER_REMINDER"
        static let logDrink = "LOG_DRINK"
        static let snooze = "SNOOZE"
        static let prefix = "wr.reminder."
        static let snoozed = "wr.snoozed"
    }

    /// iOS 最多保留 64 条待触发的本地通知，留点余量
    private let maxPending = 56
    private let scheduleDays = 7

    private let center = UNUserNotificationCenter.current()
    private let calendar = Calendar.current

    private let messages = [
        "起来接杯水吧，身体在等你",
        "喝口水，顺便让眼睛歇一会儿",
        "补水时间到，别等口渴了才喝",
        "一杯水的功夫，值得",
        "该喝水啦，保持状态"
    ]

    // MARK: - 权限

    func registerCategories() {
        let drink = UNNotificationAction(
            title: "喝了一杯",
            identifier: Identifier.logDrink,
            options: []
        )
        let snooze = UNNotificationAction(
            title: "15 分钟后提醒",
            identifier: Identifier.snooze,
            options: []
        )
        let category = UNNotificationCategory(
            identifier: Identifier.category,
            actions: [drink, snooze],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([category])
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    // MARK: - 调度

    /// 清掉旧的提醒，按当前设置重新排未来几天的提醒
    func reschedule(settings: AppSettings, lastDrink: Date?, goalMetToday: Bool) {
        center.getPendingNotificationRequests { [weak self] requests in
            guard let self else { return }
            let stale = requests
                .map(\.identifier)
                .filter { $0.hasPrefix(Identifier.prefix) }
            self.center.removePendingNotificationRequests(withIdentifiers: stale)

            let dates = self.fireDates(settings: settings, lastDrink: lastDrink, goalMetToday: goalMetToday)
            for (index, date) in dates.enumerated() {
                let components = self.calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
                let request = UNNotificationRequest(
                    identifier: Identifier.prefix + String(index),
                    content: self.content(settings: settings, index: index),
                    trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                )
                self.center.add(request)
            }
        }
    }

    /// 「稍后提醒」：单独排一条，不参与常规调度
    func snooze(minutes: Int, settings: AppSettings) {
        let request = UNNotificationRequest(
            identifier: Identifier.snoozed,
            content: content(settings: settings, index: 0),
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(minutes * 60), repeats: false)
        )
        center.add(request)
    }

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }

    func nextFireDate(settings: AppSettings, lastDrink: Date?, goalMetToday: Bool) -> Date? {
        fireDates(settings: settings, lastDrink: lastDrink, goalMetToday: goalMetToday, limit: 1).first
    }

    // MARK: - 时间计算

    /// 未来几天所有该提醒的时刻。
    ///
    /// 规则：在提醒时段内按间隔铺开；今天的第一条从「最后一次喝水 + 间隔」算起，
    /// 所以刚喝过水就会自动顺延；当天达标后（若开启）跳过今天剩下的提醒。
    func fireDates(
        settings: AppSettings,
        lastDrink: Date?,
        goalMetToday: Bool,
        now: Date = Date(),
        limit: Int? = nil
    ) -> [Date] {
        guard settings.remindEnabled, settings.interval > 0 else { return [] }

        let cap = limit ?? maxPending
        let step = TimeInterval(settings.interval * 60)
        let today = calendar.startOfDay(for: now)
        var result: [Date] = []
        var seen = Set<Date>()

        // 从 -1 开始，覆盖「跨零点时段」里属于昨晚那一段的凌晨时间
        for offset in -1..<scheduleDays {
            guard result.count < cap,
                  let day = calendar.date(byAdding: .day, value: offset, to: today),
                  let start = calendar.date(
                      bySettingHour: settings.startMinutes / 60,
                      minute: settings.startMinutes % 60,
                      second: 0,
                      of: day
                  ),
                  var end = calendar.date(
                      bySettingHour: settings.endMinutes / 60,
                      minute: settings.endMinutes % 60,
                      second: 0,
                      of: day
                  )
            else { continue }

            if settings.isOvernightWindow {
                end = calendar.date(byAdding: .day, value: 1, to: end) ?? end
            }
            if offset == 0, goalMetToday, settings.pauseWhenGoalMet {
                continue
            }

            var cursor = start
            if let lastDrink, lastDrink > start, lastDrink < end {
                cursor = max(start, lastDrink.addingTimeInterval(step))
            }

            while cursor <= end, result.count < cap {
                if cursor.timeIntervalSince(now) > 30,
                   let minute = calendar.date(
                       from: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: cursor)
                   ),
                   seen.insert(minute).inserted {
                    result.append(minute)
                }
                cursor = cursor.addingTimeInterval(step)
            }
        }

        return result.sorted()
    }

    // MARK: - 内容

    private func content(settings: AppSettings, index: Int) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "该喝水啦 💧"
        content.body = "\(messages[index % messages.count])，来一杯 \(settings.defaultCup) mL"
        content.sound = .default
        content.categoryIdentifier = Identifier.category
        content.userInfo = ["amount": settings.defaultCup]
        // 想让提醒能穿透「专注模式」，在 Xcode 里给 target 勾上
        // Time Sensitive Notifications 能力，然后把下面这行打开：
        // content.interruptionLevel = .timeSensitive
        return content
    }
}
