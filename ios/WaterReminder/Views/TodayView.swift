import SwiftUI
import UIKit
import UserNotifications

struct TodayView: View {
    @EnvironmentObject private var store: DrinkStore

    @State private var showCustomAlert = false
    @State private var customText = ""
    @State private var notificationsBlocked = false
    @State private var tick = 0

    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if notificationsBlocked { permissionCard }
                cupCard
                quickAddCard
                recordsCard
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .background(Theme.pageBackground)
        .navigationTitle(todayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task { await refreshAuthorizationState() }
        .onReceive(timer) { _ in
            tick += 1 // 让「下次提醒」文案跟着时间走
        }
        .alert("自定义水量", isPresented: $showCustomAlert) {
            TextField("毫升数，如 400", text: $customText)
                .keyboardType(.numberPad)
            Button("取消", role: .cancel) { customText = "" }
            Button("记录") { commitCustom() }
        } message: {
            Text("输入 1 - 3000 之间的数字")
        }
    }

    // MARK: - 各区块

    private var permissionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("通知未开启", systemImage: "bell.slash")
                .font(.subheadline.weight(.semibold))
            Text("没有通知权限就收不到喝水提醒，去系统设置里打开吧。")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("前往设置") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.caption.weight(.semibold))
        }
        .card()
    }

    private var cupCard: some View {
        VStack(spacing: 16) {
            CupView(
                total: store.todayTotal,
                goal: store.settings.goal,
                progress: store.progress,
                percent: store.progressPercent
            )
            .padding(.top, 8)

            Text(store.remaining > 0 ? "还差 \(store.remaining) mL，加把劲" : "今日目标已达成，喝得不错 🎉")
                .font(.footnote)
                .foregroundStyle(store.remaining > 0 ? Color.secondary : Theme.brand)

            Text(store.nextReminderText())
                .id(tick)
                .font(.caption)
                .foregroundStyle(Theme.brand)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Theme.brand.opacity(0.1), in: Capsule())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var quickAddCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("快速记录")
                .font(.headline)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                // 用下标做 id，允许两个按钮设成同样的水量
                ForEach(Array(store.settings.cups.enumerated()), id: \.offset) { _, amount in
                    Button {
                        add(amount)
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "cup.and.saucer.fill")
                                .font(.title3)
                            Text("\(amount) mL")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.brand.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.brand)
                }

                Button {
                    customText = ""
                    showCustomAlert = true
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: "square.and.pencil")
                            .font(.title3)
                        Text("自定义")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
        .card()
    }

    private var recordsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("今日记录").font(.headline)
                Spacer()
                Text("共 \(store.todayRecords.count) 次")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 4)

            if store.todayRecords.isEmpty {
                Text("还没有记录，喝第一杯吧")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
            } else {
                ForEach(store.todayRecords.reversed()) { record in
                    HStack {
                        Text(record.date, format: .dateTime.hour().minute())
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(width: 64, alignment: .leading)
                        Text("\(record.amount) mL")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Button {
                            store.delete(record)
                        } label: {
                            Image(systemName: "trash")
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 11)
                    .contentShape(Rectangle())
                    .contextMenu {
                        Button(role: .destructive) {
                            store.delete(record)
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                    Divider()
                }
            }
        }
        .card()
    }

    // MARK: - 逻辑

    private var todayTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 EEEE"
        return formatter.string(from: Date())
    }

    private func add(_ amount: Int) {
        let wasBelowGoal = store.todayTotal < store.settings.goal
        store.addDrink(amount)
        if wasBelowGoal && store.todayTotal >= store.settings.goal {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    private func commitCustom() {
        defer { customText = "" }
        guard let amount = Int(customText.trimmingCharacters(in: .whitespaces)),
              amount > 0, amount <= 3000
        else { return }
        add(amount)
    }

    private func refreshAuthorizationState() async {
        let status = await NotificationManager.shared.authorizationStatus()
        notificationsBlocked = (status == .denied)
    }
}

#Preview {
    NavigationStack {
        TodayView().environmentObject(DrinkStore.shared)
    }
}
