import Foundation

enum Area: String, CaseIterable, Identifiable, Codable {
    case health, work, finances, family, friends, partner, leisure, growth
    var id: String { rawValue }
    var title: String {
        switch self {
        case .health: return localized("Health")
        case .work: return localized("Work")
        case .finances: return localized("Finances")
        case .family: return localized("Family")
        case .friends: return localized("Friends")
        case .partner: return localized("Partner")
        case .leisure: return localized("Leisure")
        case .growth: return localized("Growth")
        }
    }
}

// Shared by touch interaction and the platform-independent geometry checks.
enum WheelInteraction {
    static func area(x: Double, y: Double) -> Area {
        let turn = (atan2(y, x) + .pi / 2 + 2 * .pi).truncatingRemainder(dividingBy: 2 * .pi)
        let index = Int((turn / (.pi / 4)).rounded()) % Area.allCases.count
        return Area.allCases[index]
    }

    static func score(x: Double, y: Double, radius: Double, area: Area) -> Int {
        guard radius > 0, radius.isFinite, x.isFinite, y.isFinite else { return 0 }
        let index = Area.allCases.firstIndex(of: area)!
        let angle = Double(index) * .pi / 4 - .pi / 2
        let projection = x * cos(angle) + y * sin(angle)
        return Int(max(0, min(10, (projection / radius * 10).rounded())))
    }
}

struct Wheel: Codable, Equatable {
    var scores = Dictionary(uniqueKeysWithValues: Area.allCases.map { ($0.rawValue, nil as Int?) })
    var notes = Dictionary(uniqueKeysWithValues: Area.allCases.map { ($0.rawValue, "") })

    func score(_ area: Area) -> Int? { scores[area.rawValue] ?? nil }
    func note(_ area: Area) -> String { notes[area.rawValue] ?? "" }
    var average: Double? {
        let values = Area.allCases.compactMap(score)
        return values.isEmpty ? nil : Double(values.reduce(0, +)) / Double(values.count)
    }
    var complete: Bool { Area.allCases.allSatisfy { score($0) != nil } }

    func valid(allowUnanswered: Bool) -> Bool {
        let keys = Set(Area.allCases.map(\.rawValue))
        return Set(scores.keys) == keys && Set(notes.keys) == keys &&
            Area.allCases.allSatisfy { area in
                (score(area).map { (0...10).contains($0) } ?? allowUnanswered) &&
                note(area).utf16.count <= 4000
            }
    }
}

struct CheckIn: Codable, Identifiable, Equatable {
    var id: String
    var at: String
    var title: String
    var scores: [String: Int?]
    var notes: [String: String]
    var wheel: Wheel { Wheel(scores: scores, notes: notes) }
    var date: Date? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: at) { return date }
        iso.formatOptions = [.withInternetDateTime]
        return iso.date(from: at)
    }

    init(wheel: Wheel, title: String, now: Date = .now) {
        id = UUID().uuidString.lowercased()
        at = ISO8601DateFormatter().string(from: now)
        self.title = title
        scores = wheel.scores
        notes = wheel.notes
    }
}

struct ReflectionState: Codable, Equatable {
    static let maximumBytes = 8_000_000
    static let maximumHistory = 5000
    var version = 2
    var locale = "en"
    var draft = Wheel()
    var history: [CheckIn] = []

    static func decode(_ data: Data) throws -> Self {
        guard data.count <= maximumBytes else { throw ReflectionError.tooLarge }
        var state = try JSONDecoder().decode(Self.self, from: data)
        guard (1...2).contains(state.version), ["en", "es"].contains(state.locale),
              state.draft.valid(allowUnanswered: true), state.history.count <= maximumHistory else {
            throw ReflectionError.invalidBackup
        }
        var ids = Set<String>()
        guard state.history.allSatisfy({
            !$0.id.isEmpty && ids.insert($0.id).inserted && $0.title.utf16.count <= 80 &&
            $0.date != nil && $0.wheel.valid(allowUnanswered: false)
        }) else { throw ReflectionError.invalidBackup }
        state.version = 2
        state.locale = "en"
        return state
    }

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(self)
        guard data.count <= Self.maximumBytes else { throw ReflectionError.tooLarge }
        return data
    }
}

enum ReflectionError: LocalizedError {
    case invalidBackup, tooLarge, incomplete, historyFull
    var errorDescription: String? {
        switch self {
        case .invalidBackup: return localized("This file is not a valid Brújula backup.")
        case .tooLarge: return localized("This data exceeds Brújula’s 8 MB limit.")
        case .incomplete: return localized("Rate all eight areas before saving a check-in.")
        case .historyFull: return localized("The history is full. Export a backup before deleting an older check-in.")
        }
    }
}

enum LocalFiles {
    static func directory() throws -> URL {
        var directory = try FileManager.default.url(for: .applicationSupportDirectory,
            in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("Brujula", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try directory.setResourceValues(values)
        return directory
    }

    static func write(_ data: Data, to url: URL) throws {
        #if os(iOS)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        #else
        try data.write(to: url, options: .atomic)
        #endif
    }

    static func read(_ url: URL, limit: Int = ReflectionState.maximumBytes) throws -> Data {
        let file = try FileHandle(forReadingFrom: url)
        defer { try? file.close() }
        var data = Data()
        while let chunk = try file.read(upToCount: min(65536, limit - data.count + 1)), !chunk.isEmpty {
            data.append(chunk)
            guard data.count <= limit else { throw ReflectionError.tooLarge }
        }
        return data
    }
}
