import SwiftUI
import Charts

struct StatsView: View {
    @EnvironmentObject private var store: DrinkStore
    @State private var range = 7

    private var days: [DayTotal] { store.dailyTotals(days: range) }
    private var goal: Int { store.settings.goal }

    private var total: Int { days.reduce(0) { $0 + $1.total } }
    private var activeDays: Int { days.filter { $0.total > 0 }.count }
    private var average: Int { activeDays == 0 ? 0 : total / activeDays }
    private var reachedDays: Int { days.filter { $0.total >= goal }.count }
    private var bestDay: DayTotal? { days.filter { $0.total > 0 }.max { $0.total < $1.total } }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Picker("范围", selection: $range) {
                    Text("最近 7 天").tag(7)
                    Text("最近 30 天").tag(30)
                }
                .pickerStyle(.segmented)

                chartCard
                summaryCard
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .background(Theme.pageBackground)
        .navigationTitle("饮水统计")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("饮水趋势").font(.headline)

            Chart {
                ForEach(days) { day in
                    BarMark(
                        x: .value("日期", day.date, unit: .day),
                        y: .value("水量", day.total)
                    )
                    .foregroundStyle(day.total >= goal ? Theme.brand : Theme.brand.opacity(0.28))
                    .cornerRadius(3)
                }

                RuleMark(y: .value("目标", goal))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(Theme.brand.opacity(0.55))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("目标 \(goal)")
                            .font(.caption2)
                            .foregroundStyle(Theme.brand)
                    }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: range == 7 ? 1 : 5)) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(date, format: range == 7 ? .dateTime.weekday(.narrow) : .dateTime.day())
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .frame(height: 200)

            Text("单位 mL，深色柱子表示当天已达标")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .card()
    }

    private var summaryCard: some View {
        VStack(spacing: 16) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 20) {
                metric(value: "\(total)", label: "总饮水量 (mL)")
                metric(value: "\(average)", label: "有记录日均 (mL)")
                metric(value: "\(reachedDays)", label: "达标天数")
                metric(value: "\(store.streak)", label: "连续达标 (天)")
            }

            if let bestDay {
                Divider()
                Text("喝得最多的一天：\(bestDay.date, format: .dateTime.month().day()) · \(bestDay.total) mL")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .card()
    }

    private func metric(value: String, label: String) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.brand)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    NavigationStack {
        StatsView().environmentObject(DrinkStore.shared)
    }
}
