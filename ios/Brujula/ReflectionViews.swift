import SwiftUI

struct RadarView: View {
    let wheel: Wheel
    var comparison: Wheel?
    var select: ((Area) -> Void)?

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let radius = min(max(20, size.width / 2 - 56), size.height / 2 - 38)
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            Canvas { context, _ in
                for level in [2, 4, 6, 8, 10] {
                    let grid = polygon(center: center, radius: radius) { _ in CGFloat(level) / 10 }
                    context.stroke(grid, with: .color(.secondary.opacity(0.23)), lineWidth: 1)
                }
                for index in Area.allCases.indices {
                    var spoke = Path()
                    spoke.move(to: center)
                    spoke.addLine(to: point(index, center, radius))
                    context.stroke(spoke, with: .color(.secondary.opacity(0.23)), lineWidth: 1)
                }
                if let comparison, comparison.average != nil {
                    let outline = polygon(center: center, radius: radius) {
                        CGFloat(comparison.score($0) ?? 0) / 10
                    }
                    context.stroke(outline, with: .color(.orange), style: StrokeStyle(lineWidth: 2, dash: [4, 4]))
                }
                if wheel.average != nil {
                    let shape = polygon(center: center, radius: radius) { CGFloat(wheel.score($0) ?? 0) / 10 }
                    context.fill(shape, with: .color(Palette.green.opacity(0.18)))
                    context.stroke(shape, with: .color(Palette.green), lineWidth: 2)
                    for (index, area) in Area.allCases.enumerated() {
                        guard let score = wheel.score(area) else { continue }
                        let mark = point(index, center, radius * CGFloat(score) / 10)
                        context.fill(Path(ellipseIn: CGRect(x: mark.x - 3, y: mark.y - 3, width: 6, height: 6)),
                                     with: .color(Palette.green))
                    }
                }
            }
            .accessibilityHidden(true)
            ForEach(Array(Area.allCases.enumerated()), id: \.element) { index, area in
                let label = point(index, center, radius + 28)
                Group {
                    if let select {
                        Button { select(area) } label: { areaLabel(area) }
                            .buttonStyle(.plain)
                    } else {
                        areaLabel(area)
                    }
                }
                .position(label)
            }
        }
        .frame(height: 275)
    }

    private func areaLabel(_ area: Area) -> some View {
        VStack(spacing: 1) {
            Text(area.title).font(.caption2)
            Text(wheel.score(area).map(String.init) ?? "—").font(.caption2.bold()).foregroundStyle(Palette.green)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .frame(width: 61, height: 44)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(area.title)
        .accessibilityValue(wheel.score(area).map { Text("\($0) out of 10") } ?? Text("Not rated"))
    }

    private func point(_ index: Int, _ center: CGPoint, _ radius: CGFloat) -> CGPoint {
        let angle = Double(index) * .pi / 4 - .pi / 2
        return CGPoint(x: center.x + radius * CGFloat(cos(angle)), y: center.y + radius * CGFloat(sin(angle)))
    }

    private func polygon(center: CGPoint, radius: CGFloat, value: (Area) -> CGFloat) -> Path {
        Path { path in
            for (index, area) in Area.allCases.enumerated() {
                let vertex = point(index, center, radius * value(area))
                if index == 0 { path.move(to: vertex) }
                else { path.addLine(to: vertex) }
            }
            path.closeSubpath()
        }
    }
}

struct AreaEditor: View {
    let area: Area
    let save: (Int?, String) -> Bool
    @Environment(\.dismiss) private var dismiss
    @State private var score: Int?
    @State private var note: String
    @State private var failed = false

    init(area: Area, wheel: Wheel, save: @escaping (Int?, String) -> Bool) {
        self.area = area
        self.save = save
        _score = State(initialValue: wheel.score(area))
        _note = State(initialValue: wheel.note(area))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("How do you feel about this area?") {
                    Picker("Score", selection: $score) {
                        Text("Not rated").tag(nil as Int?)
                        ForEach(0...10, id: \.self) { value in Text("\(value) / 10").tag(Optional(value)) }
                    }
                }
                Section("Your reflection") {
                    TextEditor(text: $note)
                        .frame(minHeight: 150)
                        .accessibilityLabel("Your reflection")
                    Text("\(note.utf16.count) / 4000")
                        .font(.caption).foregroundStyle(.secondary)
                    if failed { Text("Could not save. Your edits are still on this screen.").foregroundStyle(.red) }
                }
            }
            .navigationTitle(area.title)
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if save(score, note) { dismiss() }
                        else { failed = true }
                    }
                    .disabled(note.utf16.count > 4000)
                }
            }
        }
    }
}

struct HistoryDetail: View {
    let entry: CheckIn
    @EnvironmentObject private var store: ReflectionStore
    @Environment(\.dismiss) private var dismiss
    @State private var comparison = ""
    @State private var action: Action?
    private enum Action: String, Identifiable {
        case replace, delete
        var id: String { rawValue }
        var title: String {
            self == .replace
                ? String(localized: "Replace current draft?")
                : String(localized: "Delete this check-in?")
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let date = entry.date { Text(date, format: .dateTime.year().month().day().hour().minute()).foregroundStyle(.secondary) }
                Picker("Compare with", selection: $comparison) {
                    Text("No comparison").tag("")
                    ForEach(store.state.history.reversed().filter { $0.id != entry.id }) { item in
                        Text(item.title).tag(item.id)
                    }
                }
                RadarView(wheel: entry.wheel, comparison: other?.wheel)
                if let other { Label("Dashed line: \(other.title)", systemImage: "minus").foregroundStyle(.secondary) }
                ForEach(Area.allCases) { area in
                    VStack(alignment: .leading, spacing: 8) {
                        LabeledContent(area.title) {
                            if let score = entry.wheel.score(area) {
                                if let otherScore = other?.wheel.score(area) { Text("\(score)/10 · compared with \(otherScore)/10") }
                                else { Text("\(score)/10") }
                            }
                        }
                        if !entry.wheel.note(area).isEmpty { Text(entry.wheel.note(area)).foregroundStyle(.secondary) }
                    }
                    Divider()
                }
                Button("Use as draft") { action = .replace }.buttonStyle(.bordered)
                Button("Delete check-in", role: .destructive) { action = .delete }
            }
            .padding()
        }
        .navigationTitle(entry.title)
        .navigationBarTitleDisplayMode(.inline)
        .alert(item: $action) { action in
            Alert(title: Text(action.title),
                  message: Text(action == .replace ? "Your current scores and notes will be replaced. History will be kept." : "This check-in and its notes will be removed from history."),
                  primaryButton: .destructive(Text(action == .replace ? "Replace draft" : "Delete")) {
                var candidate = store.state
                switch action {
                case .replace: candidate.draft = entry.wheel
                case .delete: candidate.history.removeAll { $0.id == entry.id }
                }
                if store.commit(candidate) { dismiss() }
            }, secondaryButton: .cancel())
        }
    }

    private var other: CheckIn? { store.state.history.first { $0.id == comparison } }
}

struct ReminderEditor: View {
    @EnvironmentObject private var reminders: ReminderStore
    @Environment(\.dismiss) private var dismiss
    @State private var config: ReminderSchedule
    @State private var time: Date
    @State private var failure: String?

    init(schedule: ReminderSchedule) {
        _config = State(initialValue: schedule)
        _time = State(initialValue: Calendar.current.date(bySettingHour: schedule.hour, minute: schedule.minute, second: 0, of: .now) ?? .now)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Enable reminder", isOn: $config.enabled)
                    if config.enabled {
                        Picker("Frequency", selection: $config.frequency) {
                            ForEach(ReminderSchedule.Frequency.allCases) { item in Text(item.title).tag(item) }
                        }
                        if config.frequency == .weekly {
                            Picker("Day of the week", selection: $config.weekday) {
                                ForEach(Array(Calendar.current.weekdaySymbols.enumerated()), id: \.offset) { index, day in
                                    Text(day).tag(index + 1)
                                }
                            }
                        }
                        if config.frequency == .monthly {
                            Picker("Day of the month", selection: $config.monthDay) {
                                ForEach(1...31, id: \.self) { day in Text(day, format: .number).tag(day) }
                            }
                            Text("If the chosen day does not exist, the reminder uses the last day of the month.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                        DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                    }
                }
                if reminders.schedule.enabled, let next = reminders.nextDate {
                    Section("Next scheduled reminder") { Text(next, format: .dateTime.month().day().hour().minute()) }
                }
                if let failure {
                    Section { Text(failure).foregroundStyle(.red) }
                }
                Section {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        Link("Open iPhone Settings", destination: url)
                    }
                }
            }
            .navigationTitle("Reflection reminder")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(reminders.busy)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.disabled(reminders.busy)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            let parts = Calendar.current.dateComponents([.hour, .minute], from: time)
                            config.hour = parts.hour ?? 20
                            config.minute = parts.minute ?? 0
                            if await reminders.save(config) { dismiss() }
                            else {
                                failure = reminders.error ?? String(localized: "Wait for the current update and try again.")
                                reminders.error = nil
                            }
                        }
                    }
                    .disabled(reminders.busy)
                }
            }
        }
    }
}
