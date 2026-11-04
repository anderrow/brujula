import Foundation

func require(_ condition: Bool, _ message: String) {
    if !condition {
        FileHandle.standardError.write(Data((message + "\n").utf8))
        exit(1)
    }
}

let empty = ReflectionState()
let encoded = try empty.encoded()
let decoded = try ReflectionState.decode(encoded)
require(decoded == empty && decoded.draft.average == nil, "A new install must be empty after a disk round trip.")
let json = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
let draft = json["draft"] as! [String: Any]
let scores = draft["scores"] as! [String: Any]
require(scores.count == 8 && scores.values.allSatisfy { $0 is NSNull }, "Android backups require explicit nulls for unrated areas.")

let backup = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
var restored = try ReflectionState.decode(backup)
require(restored.version == 2 && restored.locale == "en", "The Android backup must migrate to the iPhone format.")
require(restored.draft.score(.health) == 0 && restored.draft.note(.health) == "Walk by the canal.", "Android scores and notes must survive migration.")
require(restored.history.count == 1 && restored.history[0].date != nil, "Android check-in history must survive migration.")
restored.draft.notes[Area.health.rawValue] = "A different note."
require(restored.history[0].wheel.note(.health) == "Walk by the canal.", "Editing the draft must not change a saved check-in.")
restored.history.append(restored.history[0])
do {
    _ = try ReflectionState.decode(restored.encoded())
    require(false, "Duplicate check-in IDs must be rejected.")
} catch {}

var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = TimeZone(identifier: "Europe/Amsterdam")!
let now = calendar.date(from: DateComponents(year: 2028, month: 1, day: 31, hour: 23))!
var schedule = ReminderSchedule()
require(!schedule.enabled && schedule.repeatingComponents()?.hour == 20, "Daily reminders must start disabled.")
schedule.frequency = .weekly
schedule.weekday = 7
require(schedule.repeatingComponents()?.weekday == 7, "Weekly reminders must preserve the selected weekday.")
schedule.frequency = .monthly
schedule.monthDay = 28
require(schedule.repeatingComponents()?.day == 28, "A monthly day present in every month can repeat directly.")
schedule.monthDay = 31
let dates = schedule.upcomingMonthDates(after: now, calendar: calendar, count: 3)
require(dates.map { calendar.component(.day, from: $0) } == [29, 31, 30], "Monthly reminders must clamp short months, including leap February.")
require(dates.allSatisfy { calendar.component(.hour, from: $0) == 20 }, "Reminders must keep local time across the daylight-saving transition.")

let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
defer { try? FileManager.default.removeItem(at: file) }
try LocalFiles.write(encoded, to: file)
let fileData = try LocalFiles.read(file)
require(fileData == encoded, "Atomic file storage must round-trip.")
do {
    _ = try LocalFiles.read(file, limit: encoded.count - 1)
    require(false, "Reading a file above the limit must fail.")
} catch {}
print("iPhone data, Android backup compatibility, and reminder checks passed.")
