import SwiftUI
import UIKit
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject private var store: DrinkStore

    @State private var showClearAlert = false
    @State private var showResetAlert = false
    @State private var authorizationStatus: UNAuthorizationStatus = .notDetermined

    var body: some View {
        Form {
            goalSection
            cupsSection
            reminderSection
            dataSection

            Section {
                HStack {
                    Text("版本")
                    Spacer()
                    Text("1.0.0").foregroundStyle(.secondary)
                }
            } footer: {
                Text("所有数据只保存在本机，不会上传。")
            }
        }
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
        .task { authorizationStatus = await NotificationManager.shared.authorizationStatus() }
        .alert("清空饮水记录？", isPresented: $showClearAlert) {
            Button("取消", role: .cancel) {}
            Button("清空", role: .destructive) { store.clearRecords() }
        } message: {
            Text("记录只保存在本机，删除后无法恢复。")
        }
        .alert("恢复默认设置？", isPresented: $showResetAlert) {
            Button("取消", role: .cancel) {}
            Button("恢复", role: .destructive) { store.resetSettings() }
        } message: {
            Text("饮水记录不会被删除。")
        }
    }

    // MARK: - 每日目标

    private var goalSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("每日目标")
                    Spacer()
                    Text("\(store.settings.goal) mL")
                        .foregroundStyle(Theme.brand)
                        .monospacedDigit()
                }
                Slider(
                    value: Binding(
                        get: { Double(store.settings.goal) },
                        set: { store.settings.goal = Int(($0 / 100).rounded()) * 100 }
                    ),
                    in: 500...5000,
                    step: 100
                )
                HStack(spacing: 8) {
                    ForEach(AppSettings.goalPresets, id: \.self) { preset in
                        Button("\(preset)") { store.settings.goal = preset }
                            .font(.footnote)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(Theme.brand.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                            .buttonStyle(.plain)
                            .foregroundStyle(Theme.brand)
                    }
                }
            }
            .padding(.vertical, 4)
        } footer: {
            Text("一般建议每天 1500 - 2500 mL，运动量大或天气炎热可适当增加。")
        }
    }

    // MARK: - 快捷杯量

    private var cupsSection: some View {
        Section {
            ForEach(Array(store.settings.cups.enumerated()), id: \.offset) { index, amount in
                HStack {
                    Text("按钮 \(index + 1)")
                    Spacer()
                    TextField(
                        "毫升",
                        value: Binding(
                            get: { store.settings.cups[index] },
                            set: { store.settings.cups[index] = min(max($0, 1), 3000) }
                        ),
                        format: .number
                    )
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                    Text("mL").foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("快捷杯量")
        } footer: {
            Text("首页「快速记录」按钮的水量。")
        }
    }

    // MARK: - 提醒

    private var reminderSection: some View {
        Section {
            Toggle("开启提醒", isOn: $store.settings.remindEnabled)

            DatePicker("开始时间", selection: timeBinding(\.startMinutes), displayedComponents: .hourAndMinute)
            DatePicker("结束时间", selection: timeBinding(\.endMinutes), displayedComponents: .hourAndMinute)

            Picker("提醒间隔", selection: $store.settings.interval) {
                ForEach(AppSettings.intervalOptions, id: \.self) { minutes in
                    Text("\(minutes) 分钟").tag(minutes)
                }
            }

            Toggle("达标后停止提醒", isOn: $store.settings.pauseWhenGoalMet)

            HStack {
                Text("下次提醒")
                Spacer()
                Text(store.nextReminderText())
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if authorizationStatus == .denied {
                Button("通知权限已关闭，前往系统设置") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .foregroundStyle(.red)
            }
        } header: {
            Text("提醒")
        } footer: {
            Text("提醒由系统本地通知发出，App 关闭时也会准时到达。刚喝过水会自动顺延下一次提醒。")
        }
    }

    // MARK: - 数据

    private var dataSection: some View {
        Section("数据") {
            Button("恢复默认设置") { showResetAlert = true }
            Button("清空饮水记录", role: .destructive) { showClearAlert = true }
        }
    }

    // MARK: -

    /// 设置里存的是分钟数，DatePicker 要的是 Date，这里做双向转换
    private func timeBinding(_ keyPath: WritableKeyPath<AppSettings, Int>) -> Binding<Date> {
        Binding(
            get: {
                let minutes = store.settings[keyPath: keyPath]
                let start = Calendar.current.startOfDay(for: Date())
                return Calendar.current.date(byAdding: .minute, value: minutes, to: start) ?? start
            },
            set: { newValue in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                store.settings[keyPath: keyPath] = (components.hour ?? 0) * 60 + (components.minute ?? 0)
            }
        )
    }
}

#Preview {
    NavigationStack {
        SettingsView().environmentObject(DrinkStore.shared)
    }
}
