import Foundation

/// 用户设置。时间用「从零点开始的分钟数」保存，避免时区/日期干扰。
struct AppSettings: Codable, Equatable {
    var goal: Int = 2000
    var cups: [Int] = [150, 250, 350, 500]
    var remindEnabled: Bool = true
    var startMinutes: Int = 8 * 60
    var endMinutes: Int = 22 * 60
    var interval: Int = 60
    var pauseWhenGoalMet: Bool = true

    static let intervalOptions = [30, 45, 60, 90, 120]
    static let goalPresets = [1500, 2000, 2500, 3000]

    /// 提醒时段是否跨零点，比如 22:00 - 02:00
    var isOvernightWindow: Bool { endMinutes <= startMinutes }

    /// 默认杯量，用于通知里的「喝了」快捷操作
    var defaultCup: Int { cups.count > 1 ? cups[1] : (cups.first ?? 250) }

    init() {}

    /// 宽松解码：旧版本存档里缺字段时用默认值补齐，而不是整体解码失败
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = AppSettings()
        goal = try container.decodeIfPresent(Int.self, forKey: .goal) ?? fallback.goal
        cups = try container.decodeIfPresent([Int].self, forKey: .cups) ?? fallback.cups
        remindEnabled = try container.decodeIfPresent(Bool.self, forKey: .remindEnabled) ?? fallback.remindEnabled
        startMinutes = try container.decodeIfPresent(Int.self, forKey: .startMinutes) ?? fallback.startMinutes
        endMinutes = try container.decodeIfPresent(Int.self, forKey: .endMinutes) ?? fallback.endMinutes
        interval = try container.decodeIfPresent(Int.self, forKey: .interval) ?? fallback.interval
        pauseWhenGoalMet = try container.decodeIfPresent(Bool.self, forKey: .pauseWhenGoalMet) ?? fallback.pauseWhenGoalMet
        if cups.isEmpty { cups = fallback.cups }
    }
}

extension Int {
    /// 分钟数 -> "08:00"
    var asClockText: String {
        String(format: "%02d:%02d", self / 60, self % 60)
    }
}
