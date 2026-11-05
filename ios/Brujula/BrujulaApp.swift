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
    @AppStorage(AppLanguage.preferenceKey) private var language = AppLanguage.system.rawValue
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(store)
                .environmentObject(reminders)
                .environment(\.locale, (AppLanguage(rawValue: language) ?? .system).locale)
                .tint(Palette.green)
                .preferredColorScheme(.light)
                .task(id: phase) {
                    if phase == .active { await reminders.refresh() }
                }
                .task(id: language) {
                    if phase == .active { await reminders.refresh() }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
                    Task { await reminders.refresh() }
                }
        }
    }
}

enum Palette {
    static let green = color(0x206755)
    static let background = color(0xF7F6F1)
    static let paper = color(0xFFFEFA)
    static let ink = color(0x263E35)
    static let muted = color(0x778178)
    static let line = color(0xE3E6DC)
    static let pale = color(0xE8EEE4)
    static let warm = color(0xF0DFCD)

    static func color(_ hex: UInt32) -> Color {
        Color(red: Double((hex >> 16) & 255) / 255,
              green: Double((hex >> 8) & 255) / 255,
              blue: Double(hex & 255) / 255)
    }
}

extension View {
    func reflectionCard() -> some View {
        padding(18)
            .background(Palette.paper, in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(Palette.line, lineWidth: 1))
    }
}
