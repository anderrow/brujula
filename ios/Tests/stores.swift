import Foundation
import UserNotifications

@MainActor
final class TestNotifications: ReminderNotifications {
    var requests: [String: UNNotificationRequest] = [:]
    var removed: [String] = []
    var deliveredRemoved: [String] = []
    var failAdds = 0
    func authorizationStatus() async -> UNAuthorizationStatus { .authorized }
    func requestAuthorization() async throws -> Bool { true }
    func pending() async -> [UNNotificationRequest] { Array(requests.values) }
    func add(_ request: UNNotificationRequest) async throws {
        if failAdds > 0 { failAdds -= 1; throw CocoaError(.fileWriteUnknown) }
        requests[request.identifier] = request
    }
    func removePending(_ ids: [String]) { removed += ids; for id in ids { requests.removeValue(forKey: id) } }
    func deliveredIDs() async -> [String] { ["brujula.reflection.delivered", "unrelated"] }
    func removeDelivered(_ ids: [String]) { deliveredRemoved += ids }
}

@main
struct StoreChecks {
    @MainActor
    static func main() async throws {
        func check(_ condition: @autoclosure () -> Bool, _ message: String) {
            if !condition() { fatalError(message) }
        }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let reflectionsURL = directory.appendingPathComponent("reflections.json")
        let remindersURL = directory.appendingPathComponent("reminder.json")
        let corrupt = Data("{preserve these original bytes".utf8)
        try corrupt.write(to: reflectionsURL)
        let reflections = ReflectionStore(directory: { directory })
        check(!reflections.ready, "Invalid reflections must enter recovery.")
        let original = try reflections.originalData()
        check(original == corrupt, "Recovery must export exact original bytes.")
        var valid = ReflectionState(); valid.draft.notes["health"] = "Retained reflection"
        try valid.encoded().write(to: reflectionsURL)
        reflections.reload()
        check(reflections.ready && reflections.state == valid, "Retry must recover without reinstalling.")

        let notifications = TestNotifications()
        let content = UNMutableNotificationContent(); content.body = "Existing invitation"
        let pending = UNNotificationRequest(identifier: "brujula.reflection.existing", content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 120, repeats: false))
        notifications.requests[pending.identifier] = pending
        try corrupt.write(to: remindersURL)
        let reminders = ReminderStore(directory: { directory }, notifications: notifications)
        check(!reminders.loaded, "Malformed preferences must remain a failed load.")
        await reminders.refresh()
        check(notifications.requests[pending.identifier] != nil && notifications.removed.isEmpty,
              "Failed reminder initialization must never cancel existing requests.")
        var enabled = ReminderSchedule(); enabled.enabled = true
        try JSONEncoder().encode(enabled).write(to: remindersURL)
        await reminders.refresh()
        check(reminders.loaded && reminders.schedule.enabled, "Read retry must load the original schedule.")

        let snapshot = Set(notifications.requests.keys)
        let failingSave = ReminderStore(directory: { directory }, write: { _, _ in throw CocoaError(.fileWriteNoPermission) }, notifications: notifications)
        var changed = enabled; changed.frequency = .weekly
        let saved = await failingSave.save(changed)
        check(!saved && Set(notifications.requests.keys) == snapshot, "A preference write failure must restore actual requests.")
        check(notifications.deliveredRemoved.isEmpty, "Failed replacement must retain delivered notifications.")

        notifications.failAdds = 1
        let failedRegistration = await reminders.save(changed)
        check(!failedRegistration && Set(notifications.requests.keys) == snapshot, "Failed notification registration must roll back actual requests.")

        try corrupt.write(to: remindersURL)
        let invalidReminders = ReminderStore(directory: { directory }, notifications: notifications)
        let failingReflections = ReflectionStore(directory: { directory }, write: { _, _ in throw CocoaError(.fileWriteNoPermission) })
        let reset = await invalidReminders.resetReflections(failingReflections)
        let reminderBytes = try Data(contentsOf: remindersURL)
        let reflectionBytes = try Data(contentsOf: reflectionsURL)
        check(!reset && reminderBytes == corrupt && !invalidReminders.loaded, "Failed reset must restore invalid preference bytes and validity state.")
        check(Set(notifications.requests.keys) == snapshot && notifications.deliveredRemoved.isEmpty,
              "Failed compound reset must preserve pending and delivered notifications.")
        let expectedReflections = try valid.encoded()
        check(reflectionBytes == expectedReflections, "Failed reset must preserve the original reflections.")
        let completed = await invalidReminders.resetReflections(reflections)
        check(completed && notifications.requests.isEmpty, "Confirmed reset must clear reflections and pending requests.")
        check(reflections.ready && reflections.state == ReflectionState(), "Confirmed reset must leave a usable fresh installation.")
        print("Native store recovery, notification rollback and compound reset checks passed.")
    }
}
