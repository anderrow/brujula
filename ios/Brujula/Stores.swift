import SwiftUI
import UniformTypeIdentifiers
import UserNotifications

@MainActor
final class ReflectionStore: ObservableObject {
    @Published private(set) var state = ReflectionState()
    @Published var error: String?
    @Published private(set) var ready = false
    private var url: URL?

    init() {
        do {
            let url = try LocalFiles.directory().appendingPathComponent("reflections.json")
            self.url = url
            if FileManager.default.fileExists(atPath: url.path) {
                state = try ReflectionState.decode(LocalFiles.read(url))
            }
            ready = true
        } catch {
            self.error = localized("Your saved reflections could not be opened. The original file has not been changed.")
        }
    }

    @discardableResult
    func commit(_ candidate: ReflectionState) -> Bool {
        guard let url else {
            error = localized("Local storage is unavailable. Try opening Brújula again.")
            return false
        }
        do {
            try LocalFiles.write(candidate.encoded(), to: url)
            state = candidate
            ready = true
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func edit(_ area: Area, score: Int?, note: String) -> Bool {
        var candidate = state
        candidate.draft.scores.updateValue(score, forKey: area.rawValue)
        candidate.draft.notes[area.rawValue] = note
        guard candidate.draft.valid(allowUnanswered: true) else {
            error = localized("Keep notes to 4,000 characters or fewer.")
            return false
        }
        return commit(candidate)
    }

    func saveCheckIn(_ title: String) -> Bool {
        guard state.draft.complete else {
            error = ReflectionError.incomplete.localizedDescription
            return false
        }
        guard state.history.count < ReflectionState.maximumHistory else {
            error = ReflectionError.historyFull.localizedDescription
            return false
        }
        var candidate = state
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        candidate.history.append(CheckIn(wheel: state.draft, title: title.isEmpty ? localized("My check-in") : title))
        return commit(candidate)
    }
}

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    let data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw ReflectionError.invalidBackup }
        self.data = data
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

@MainActor
final class ReminderStore: ObservableObject {
    @Published private(set) var schedule = ReminderSchedule()
    @Published private(set) var canNotify = false
    @Published private(set) var nextDate: Date?
    @Published private(set) var busy = false
    @Published var error: String?
    private let center = UNUserNotificationCenter.current()
    private let prefix = "brujula.reflection."
    private var url: URL?

    init() {
        do {
            let url = try LocalFiles.directory().appendingPathComponent("reminder.json")
            self.url = url
            if FileManager.default.fileExists(atPath: url.path) {
                let stored = try JSONDecoder().decode(ReminderSchedule.self, from: LocalFiles.read(url, limit: 16384))
                guard stored.valid else { throw ReflectionError.invalidBackup }
                schedule = stored
            }
        } catch {
            self.error = localized("The saved reminder could not be opened.")
        }
    }

    private func allowed() async -> Bool {
        switch await center.notificationSettings().authorizationStatus {
        case .authorized, .provisional, .ephemeral: return true
        default: return false
        }
    }

    func refresh() async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        canNotify = await allowed()
        do {
            if !schedule.enabled || canNotify { try await reconcile(schedule) }
            else { nextDate = nil }
        } catch { self.error = localized("The reminder could not be refreshed. Open Reminders and save it again.") }
    }

    func save(_ next: ReminderSchedule) async -> Bool {
        guard !busy, next.valid, let url else { return false }
        busy = true
        defer { busy = false }
        do {
            if next.enabled {
                if await center.notificationSettings().authorizationStatus == .notDetermined {
                    _ = try await center.requestAuthorization(options: [.alert, .sound])
                }
                canNotify = await allowed()
                guard canNotify else {
                    error = localized("Notifications are disabled. You can enable them in iPhone Settings.")
                    return false
                }
            }
            try await reconcile(next)
            do { try LocalFiles.write(JSONEncoder().encode(next), to: url) }
            catch {
                try? await reconcile(schedule)
                throw error
            }
            schedule = next
            return true
        } catch {
            try? await reconcile(schedule)
            self.error = localized("The reminder could not be saved.")
            return false
        }
    }

    private func requests(for config: ReminderSchedule) -> [UNNotificationRequest] {
        guard config.enabled else { return [] }
        let content = UNMutableNotificationContent()
        content.title = "Brújula"
        content.body = localized("Take a moment to check in with yourself.")
        content.sound = .default
        if var match = config.repeatingComponents() {
            match.calendar = Calendar(identifier: .gregorian)
            let trigger = UNCalendarNotificationTrigger(dateMatching: match, repeats: true)
            return [UNNotificationRequest(identifier: prefix + "recurring", content: content, trigger: trigger)]
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .autoupdatingCurrent
        return config.upcomingMonthDates(after: .now, calendar: calendar).map { date in
            var match = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            match.calendar = Calendar(identifier: .gregorian)
            let id = prefix + "\(match.year!)-\(match.month!)-\(match.day!)"
            let trigger = UNCalendarNotificationTrigger(dateMatching: match, repeats: false)
            return UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        }
    }

    private func reconcile(_ config: ReminderSchedule) async throws {
        let existing = await center.pendingNotificationRequests().filter { $0.identifier.hasPrefix(prefix) }
        let desired = requests(for: config)
        let desiredIDs = Set(desired.map(\.identifier))
        let obsolete = existing.map(\.identifier).filter { !desiredIDs.contains($0) }
        if !obsolete.isEmpty { center.removePendingNotificationRequests(withIdentifiers: obsolete) }
        for request in desired {
            let trigger = request.trigger as? UNCalendarNotificationTrigger
            let previousRequest = existing.first { $0.identifier == request.identifier }
            let previous = previousRequest?.trigger as? UNCalendarNotificationTrigger
            let sameText = previousRequest?.content.title == request.content.title && previousRequest?.content.body == request.content.body
            if previous?.dateComponents != trigger?.dateComponents || previous?.repeats != trigger?.repeats || !sameText {
                try await center.add(request)
            }
        }
        if !config.enabled {
            let delivered = await center.deliveredNotifications().map { $0.request.identifier }
            center.removeDeliveredNotifications(withIdentifiers: delivered.filter { $0.hasPrefix(prefix) })
        }
        nextDate = desired.compactMap { ($0.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate() }.min()
    }
}
