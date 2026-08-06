import Foundation

/// 一次饮水记录
struct DrinkRecord: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var amount: Int
    var date: Date

    init(id: UUID = UUID(), amount: Int, date: Date = Date()) {
        self.id = id
        self.amount = amount
        self.date = date
    }
}

/// 统计页用的按天汇总
struct DayTotal: Identifiable, Equatable {
    var date: Date
    var total: Int

    var id: Date { date }
}
