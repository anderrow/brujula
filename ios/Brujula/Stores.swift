import SwiftUI
import UniformTypeIdentifiers
import UserNotifications

@MainActor
final class ReflectionStore: ObservableObject {
    @Published private(set) var state = ReflectionState()
    @Published var error: String?
    @Published private(set) var ready = false
    private var url: URL?
    private let directory: () throws -> URL
    private let readFile: (URL) throws -> Data
    private let writeFile: (Data, URL) throws -> Void

    init(directory: @escaping () throws -> URL = { try LocalFiles.directory() },
         read: @escaping (URL) throws -> Data = { try LocalFiles.read($0, limit: 32_000_000) },
         write: @escaping (Data, URL) throws -> Void = { try LocalFiles.write($0, to: $1) }) {
        self.directory = directory; self.readFile = read; self.writeFile = write
        reload()
    }

    func reload() {
        do {
            let target = try directory().appendingPathComponent("reflections.json")
            url = target
            let candidate = FileManager.default.fileExists(atPath: target.path) ? try ReflectionState.decode(readFile(target)) : ReflectionState()
            state = candidate; ready = true; error = nil
        } catch {
            ready = false
            self.error = localized("Your saved reflections could not be opened. The original file has not been changed.")
        }
    }

    func originalData() throws -> Data {
        let target = try directory().appendingPathComponent("reflections.json")
        return try readFile(target)
    }

    @discardableResult
    func commit(_ candidate: ReflectionState) -> Bool {
        do {
            let target = try url ?? directory().appendingPathComponent("reflections.json")
            try writeFile(candidate.encoded(), target)
            url = target
            state = candidate
            ready = true
            error = nil
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
protocol ReminderNotifications {
    func authorizationStatus() async -> UNAuthorizationStatus
    func requestAuthorization() async throws -> Bool
    func pending() async -> [UNNotificationRequest]
    func add(_ request: UNNotificationRequest) async throws
    func removePending(_ ids: [String])
    func deliveredIDs() async -> [String]
    func removeDelivered(_ ids: [String])
}

@MainActor
private final class SystemReminderNotifications: ReminderNotifications {
    private let center = UNUserNotificationCenter.current()
    func authorizationStatus() async -> UNAuthorizationStatus { await center.notificationSettings().authorizationStatus }
    func requestAuthorization() async throws -> Bool { try await center.requestAuthorization(options: [.alert, .sound]) }
    func pending() async -> [UNNotificationRequest] { await center.pendingNotificationRequests() }
    func add(_ request: UNNotificationRequest) async throws { try await center.add(request) }
    func removePending(_ ids: [String]) { center.removePendingNotificationRequests(withIdentifiers: ids) }
    func deliveredIDs() async -> [String] { await center.deliveredNotifications().map { $0.request.identifier } }
    func removeDelivered(_ ids: [String]) { center.removeDeliveredNotifications(withIdentifiers: ids) }
}

@MainActor
final class ReminderStore: ObservableObject {
    @Published private(set) var schedule = ReminderSchedule()
    @Published private(set) var canNotify = false
    @Published private(set) var nextDate: Date?
    @Published private(set) var busy = false
    @Published private(set) var loaded = false
    @Published private(set) var registrationFailed = false
    @Published var error: String?
    private let center: ReminderNotifications
    private let prefix = "brujula.reflection."
    private var url: URL?
    private let directory: () throws -> URL
    private let readFile: (URL) throws -> Data
    private let writeFile: (Data, URL) throws -> Void

    init(directory: @escaping () throws -> URL = { try LocalFiles.directory() },
         read: @escaping (URL) throws -> Data = { try LocalFiles.read($0, limit: 32_000_000) },
         write: @escaping (Data, URL) throws -> Void = { try LocalFiles.write($0, to: $1) },
         notifications: ReminderNotifications? = nil) {
        self.directory = directory; self.readFile = read; self.writeFile = write
        center = notifications ?? SystemReminderNotifications()
        do { try load() }
        catch { self.error = localized("The saved reminder could not be opened.") }
    }

    private func load() throws {
        let target = try directory().appendingPathComponent("reminder.json")
        url = target
        let stored = FileManager.default.fileExists(atPath: target.path) ? try JSONDecoder().decode(ReminderSchedule.self, from: readFile(target)) : ReminderSchedule()
        guard stored.valid else { throw ReflectionError.invalidBackup }
        schedule = stored; loaded = true
    }

    private func allowed() async -> Bool {
        switch await center.authorizationStatus() {
        case .authorized, .provisional, .ephemeral: return true
        default: return false
        }
    }

    func refresh() async {
        guard !busy else { return }
        busy = true; defer { busy = false }
        do {
            if !loaded { try load() }
            canNotify = await allowed()
            if !schedule.enabled || canNotify { _ = try await replace(schedule); if !schedule.enabled { await clearDelivered() } }
            else { nextDate = nil }
            error = nil
        } catch { self.error = localized("The reminder could not be refreshed. Open Reminders and save it again.") }
    }

    func save(_ next: ReminderSchedule) async -> Bool {
        guard !busy, next.valid else { return false }
        busy = true; defer { busy = false }
        error = nil
        do {
            let target = try url ?? directory().appendingPathComponent("reminder.json")
            if next.enabled {
                if await center.authorizationStatus() == .notDetermined { _ = try await center.requestAuthorization() }
                canNotify = await allowed()
                guard canNotify else {
                    error = localized("Notifications are disabled. You can enable them in iPhone Settings."); return false
                }
            }
            let snapshot = try await replace(next)
            do { try writeFile(JSONEncoder().encode(next), target) }
            catch { try await restoreRequests(snapshot); throw error }
            url = target; schedule = next; loaded = true; error = nil
            if !next.enabled { await clearDelivered() }
            return true
        } catch {
            if self.error == nil { self.error = localized("The reminder could not be saved.") }
            return false
        }
    }

    func resetReflections(_ reflections: ReflectionStore) async -> Bool {
        guard !busy else { return false }
        busy = true; defer { busy = false }
        error = nil
        let previous = schedule, wasLoaded = loaded
        var original: Data?, target: URL?, preferencesChanged = false
        let snapshot = await center.pending().filter { $0.identifier.hasPrefix(prefix) }
        do {
            let destination = try url ?? directory().appendingPathComponent("reminder.json")
            target = destination
            if FileManager.default.fileExists(atPath: destination.path) { original = try readFile(destination) }
            _ = try await replace(ReminderSchedule())
            try writeFile(JSONEncoder().encode(ReminderSchedule()), destination); preferencesChanged = true
            guard reflections.commit(ReflectionState()) else { throw CocoaError(.fileWriteUnknown) }
            url = destination; schedule = ReminderSchedule(); loaded = true; nextDate = nil; error = nil
            await clearDelivered(); return true
        } catch {
            var restoredPreferences = true
            do {
                if preferencesChanged, let target {
                    if let original { try writeFile(original, target) }
                    else { try FileManager.default.removeItem(at: target) }
                }
            } catch { restoredPreferences = false }
            do { try await restoreRequests(snapshot) }
            catch { registrationFailed = true }
            schedule = previous; loaded = wasLoaded && restoredPreferences
            if !restoredPreferences { registrationFailed = true; nextDate = nil }
            if registrationFailed { self.error = localized("Some reminders could not be restored. Open Reminders and save again.") }
            if self.error == nil { self.error = localized("The reminder could not be saved.") }
            return false
        }
    }

    private func requests(for config: ReminderSchedule) -> [UNNotificationRequest] {
        guard config.enabled else { return [] }
        let content = UNMutableNotificationContent()
        content.title = "Brújula"; content.body = localized("Take a moment to check in with yourself."); content.sound = .default
        if var match = config.repeatingComponents() {
            match.calendar = Calendar(identifier: .gregorian)
            return [UNNotificationRequest(identifier: prefix + "recurring", content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: match, repeats: true))]
        }
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = .autoupdatingCurrent
        return config.upcomingMonthDates(after: .now, calendar: calendar).map { date in
            var match = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            match.calendar = Calendar(identifier: .gregorian)
            return UNNotificationRequest(identifier: prefix + "\(match.year!)-\(match.month!)-\(match.day!)", content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: match, repeats: false))
        }
    }

    private func restoreRequests(_ snapshot: [UNNotificationRequest]) async throws {
        registrationFailed = true; nextDate = nil
        center.removePending(await center.pending().filter { $0.identifier.hasPrefix(prefix) }.map(\.identifier))
        do { for request in snapshot { try await center.add(request) } }
        catch { self.error = localized("Some reminders could not be restored. Open Reminders and save again."); nextDate = nil; throw error }
        nextDate = nextTrigger(in: snapshot); registrationFailed = false
    }

    private func nextTrigger(in requests: [UNNotificationRequest]) -> Date? {
        requests.compactMap {
            ($0.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate()
                ?? ($0.trigger as? UNTimeIntervalNotificationTrigger)?.nextTriggerDate()
        }.min()
    }

    private func clearDelivered() async {
        center.removeDelivered(await center.deliveredIDs().filter { $0.hasPrefix(prefix) })
    }

    private func replace(_ config: ReminderSchedule) async throws -> [UNNotificationRequest] {
        let existing = await center.pending().filter { $0.identifier.hasPrefix(prefix) }
        let desired = requests(for: config)
        let desiredIDs = Set(desired.map(\.identifier))
        registrationFailed = true; nextDate = nil
        do {
            center.removePending(existing.map(\.identifier).filter { !desiredIDs.contains($0) })
            for request in desired {
                let prior = existing.first { $0.identifier == request.identifier }
                let old = prior?.trigger as? UNCalendarNotificationTrigger, next = request.trigger as? UNCalendarNotificationTrigger
                if old?.dateComponents != next?.dateComponents || old?.repeats != next?.repeats || prior?.content.body != request.content.body {
                    try await center.add(request)
                }
            }
        } catch { try await restoreRequests(existing); throw error }
        nextDate = nextTrigger(in: desired); registrationFailed = false
        return existing
    }
}
