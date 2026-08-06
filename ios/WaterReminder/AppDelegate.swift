import UIKit
import UserNotifications

/// 负责通知的前台展示和「喝了一杯 / 稍后提醒」两个快捷操作
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        NotificationManager.shared.registerCategories()
        return true
    }

    /// App 在前台时也把提醒横幅显示出来
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let amount = response.notification.request.content.userInfo["amount"] as? Int

        switch response.actionIdentifier {
        case NotificationManager.Identifier.logDrink:
            await MainActor.run {
                let store = DrinkStore.shared
                store.addDrink(amount ?? store.settings.defaultCup)
            }
        case NotificationManager.Identifier.snooze:
            let settings = await MainActor.run { DrinkStore.shared.settings }
            NotificationManager.shared.snooze(minutes: 15, settings: settings)
        default:
            break
        }
    }
}
