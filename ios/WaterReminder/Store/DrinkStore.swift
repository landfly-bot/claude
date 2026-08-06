import Foundation
import SwiftUI

/// 数据中心：饮水记录 + 设置，持久化在 UserDefaults（JSON），全部留在本机。
///
/// 约定只在主线程访问：SwiftUI 视图和通知回调都在主线程，
/// AppDelegate 里的调用统一包在 `MainActor.run` 中。
final class DrinkStore: ObservableObject {
    static let shared = DrinkStore()

    private enum Key {
        static let records = "wr.records"
        static let settings = "wr.settings"
    }

    @Published private(set) var records: [DrinkRecord] = []

    @Published var settings: AppSettings {
        didSet {
            guard settings != oldValue else { return }
            persistSettings()
            rescheduleReminders()
        }
    }

    private let defaults: UserDefaults
    private let calendar = Calendar.current

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.settings = Self.loadSettings(from: defaults)
        self.records = Self.loadRecords(from: defaults)
    }

    // MARK: - 读取

    var todayRecords: [DrinkRecord] {
        records(on: Date())
    }

    var todayTotal: Int {
        total(on: Date())
    }

    var lastDrinkDate: Date? {
        records.last?.date
    }

    /// 已完成比例，0...1（超额时截断到 1，用于水位高度）
    var progress: Double {
        guard settings.goal > 0 else { return 0 }
        return min(Double(todayTotal) / Double(settings.goal), 1)
    }

    /// 真实完成百分比，可以超过 100
    var progressPercent: Int {
        guard settings.goal > 0 else { return 0 }
        return Int((Double(todayTotal) / Double(settings.goal) * 100).rounded())
    }

    var remaining: Int {
        max(settings.goal - todayTotal, 0)
    }

    var goalMetToday: Bool {
        todayTotal >= settings.goal
    }

    func records(on date: Date) -> [DrinkRecord] {
        let day = calendar.startOfDay(for: date)
        return records.filter { calendar.isDate($0.date, inSameDayAs: day) }
    }

    func total(on date: Date) -> Int {
        records(on: date).reduce(0) { $0 + $1.amount }
    }

    /// 最近 n 天的汇总，从旧到新，最后一项是今天
    func dailyTotals(days: Int) -> [DayTotal] {
        let today = calendar.startOfDay(for: Date())
        var buckets: [Date: Int] = [:]
        for record in records {
            let day = calendar.startOfDay(for: record.date)
            buckets[day, default: 0] += record.amount
        }
        return (0..<days).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return DayTotal(date: day, total: buckets[day] ?? 0)
        }
    }

    /// 连续达标天数。今天还在进行中，没达标也不算中断。
    var streak: Int {
        let today = calendar.startOfDay(for: Date())
        var count = 0
        for offset in 0..<365 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { break }
            if total(on: day) >= settings.goal {
                count += 1
            } else if offset > 0 {
                break
            }
        }
        return count
    }

    // MARK: - 写入

    func addDrink(_ amount: Int, at date: Date = Date()) {
        guard amount > 0 else { return }
        records.append(DrinkRecord(amount: amount, date: date))
        records.sort { $0.date < $1.date }
        persistRecords()
        rescheduleReminders()
    }

    func delete(_ record: DrinkRecord) {
        records.removeAll { $0.id == record.id }
        persistRecords()
        rescheduleReminders()
    }

    func clearRecords() {
        records = []
        persistRecords()
        rescheduleReminders()
    }

    func resetSettings() {
        settings = AppSettings()
    }

    // MARK: - 提醒

    func rescheduleReminders() {
        NotificationManager.shared.reschedule(
            settings: settings,
            lastDrink: lastDrinkDate,
            goalMetToday: goalMetToday
        )
    }

    /// 下一次提醒的展示文案
    func nextReminderText() -> String {
        guard settings.remindEnabled else { return "提醒已关闭" }
        if settings.pauseWhenGoalMet && goalMetToday { return "今日已达标，好好休息" }
        guard let next = NotificationManager.shared.nextFireDate(
            settings: settings,
            lastDrink: lastDrinkDate,
            goalMetToday: goalMetToday
        ) else {
            return "暂无提醒"
        }
        let minutes = max(Int(next.timeIntervalSinceNow / 60), 0)
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        if minutes < 60 {
            return "下次提醒 \(formatter.string(from: next))（约 \(minutes) 分钟后）"
        }
        return "下次提醒 \(formatter.string(from: next))"
    }

    // MARK: - 持久化

    private func persistRecords() {
        if let data = try? JSONEncoder().encode(records) {
            defaults.set(data, forKey: Key.records)
        }
    }

    private func persistSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            defaults.set(data, forKey: Key.settings)
        }
    }

    private static func loadRecords(from defaults: UserDefaults) -> [DrinkRecord] {
        guard let data = defaults.data(forKey: Key.records),
              let decoded = try? JSONDecoder().decode([DrinkRecord].self, from: data)
        else { return [] }
        return decoded.sorted { $0.date < $1.date }
    }

    private static func loadSettings(from defaults: UserDefaults) -> AppSettings {
        guard let data = defaults.data(forKey: Key.settings),
              let decoded = try? JSONDecoder().decode(AppSettings.self, from: data)
        else { return AppSettings() }
        return decoded
    }
}
