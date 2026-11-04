import SwiftUI
import UserNotifications

final class ApplicationDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}

@main
@MainActor
struct BrujulaApp: App {
    @UIApplicationDelegateAdaptor(ApplicationDelegate.self) private var delegate
    @StateObject private var store = ReflectionStore()
    @StateObject private var reminders = ReminderStore()
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(store)
                .environmentObject(reminders)
                .tint(Palette.green)
                .task(id: phase) {
                    if phase == .active { await reminders.refresh() }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
                    Task { await reminders.refresh() }
                }
        }
    }
}

enum Palette {
    static let green = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.49, green: 0.81, blue: 0.69, alpha: 1)
            : UIColor(red: 0.125, green: 0.404, blue: 0.333, alpha: 1)
    })
}
