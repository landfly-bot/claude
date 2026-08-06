import SwiftUI

@main
struct WaterReminderApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = DrinkStore.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .tint(Theme.brand)
                .task {
                    await NotificationManager.shared.requestAuthorization()
                    store.rescheduleReminders()
                }
        }
        .onChange(of: scenePhase) { _, phase in
            // 回到前台时重新排一次：跨天了、或通知里记过水，都要刷新
            if phase == .active {
                store.rescheduleReminders()
            }
        }
    }
}
