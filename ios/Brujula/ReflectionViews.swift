import SwiftUI

extension Area {
    var symbol: String {
        switch self {
        case .health: return "heart.text.square"
        case .work: return "briefcase"
        case .finances: return "wallet.pass"
        case .family: return "house"
        case .friends: return "person.2"
        case .partner: return "heart"
        case .leisure: return "sun.max"
        case .growth: return "leaf"
        }
    }

    var color: Color {
        let colors: [UInt32] = [0x427F69, 0x608FA3, 0xB38A45, 0xC48469,
                                0x9B8AAD, 0xB56F80, 0x6F9B8E, 0x8C9755]
        return Palette.color(colors[Area.allCases.firstIndex(of: self)!])
    }
}

struct AreaBadge: View {
    let area: Area
    var body: some View {
        Image(systemName: area.symbol)
            .font(.system(.title3).weight(.regular))
            .foregroundStyle(area.color)
            .frame(width: 34, height: 34)
            .background(area.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 11))
            .accessibilityHidden(true)
    }
}

struct RadarView: View {
    let wheel: Wheel
    var comparison: Wheel?
    var select: ((Area) -> Void)?
    var update: ((Area, Int) -> Bool)?
    private struct DragPreview {
        let area: Area
        let score: Int
    }
    @GestureState private var drag: DragPreview?

    var body: some View {
        GeometryReader { geometry in
            let scale = geometry.size.width / 360
            let radius = 113 * scale
            let center = CGPoint(x: geometry.size.width / 2, y: 168 * scale)
            ZStack(alignment: .topLeading) {
                Canvas { context, _ in
                    for level in [2, 4, 6, 8, 10] {
                        let grid = polygon(center: center, radius: radius) { _ in CGFloat(level) / 10 }
                        context.stroke(grid, with: .color(Palette.line), lineWidth: 1)
                        context.draw(Text("\(level)").font(.system(size: 7)).foregroundColor(Palette.muted),
                                     at: CGPoint(x: center.x + 8 * scale, y: center.y - radius * CGFloat(level) / 10))
                    }
                    for index in Area.allCases.indices {
                        var spoke = Path()
                        spoke.move(to: center)
                        spoke.addLine(to: point(index, center, radius))
                        context.stroke(spoke, with: .color(Palette.line), lineWidth: 1)
                    }
                    if let comparison, comparison.average != nil {
                        let outline = polygon(center: center, radius: radius) {
                            CGFloat(comparison.score($0) ?? 0) / 10
                        }
                        context.fill(outline, with: .color(Palette.color(0xC9A58A).opacity(0.08)))
                        context.stroke(outline, with: .color(Palette.color(0xC9A58A)),
                                       style: StrokeStyle(lineWidth: 1.8, dash: [4, 4]))
                    }
                    if wheel.average != nil || drag != nil {
                        let shape = polygon(center: center, radius: radius) { CGFloat(score($0) ?? 0) / 10 }
                        context.fill(shape, with: .color(Palette.green.opacity(0.16)))
                        context.stroke(shape, with: .color(Palette.color(0x427F69)), lineWidth: 2)
                    }
                }
                .contentShape(Rectangle())
                .gesture(SpatialTapGesture().onEnded { tap in
                    let dx = tap.location.x - center.x
                    let dy = tap.location.y - center.y
                    guard hypot(dx, dy) <= radius + 12 else { return }
                    select?(WheelInteraction.area(x: Double(dx), y: Double(dy)))
                })
                .accessibilityHidden(true)

                ForEach(Array(Area.allCases.enumerated()), id: \.element) { index, area in
                    let label = point(index, center, 145 * scale)
                    Group {
                        if let select {
                            Button { select(area) } label: { areaLabel(area) }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("wheel-area-\(area.rawValue)")
                        } else {
                            areaLabel(area)
                        }
                    }
                    .position(label)
                }

                ForEach(Array(Area.allCases.enumerated()), id: \.element) { index, area in
                    let value = score(area)
                    // Hollow handles invite a first rating without assigning a sample score.
                    let mark = point(index, center, radius * CGFloat(value ?? 5) / 10)
                    if let update {
                        ZStack {
                            Circle().fill(area.color.opacity(drag?.area == area ? 0.15 : 0.001))
                            Circle().fill(value == nil ? Palette.paper : area.color)
                                .frame(width: value == nil ? 10 : 9, height: value == nil ? 10 : 9)
                                .overlay(Circle().stroke(value == nil ? area.color : Palette.paper, lineWidth: 2))
                        }
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                        .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named("radar"))
                            .updating($drag) { gesture, preview, _ in
                                guard hypot(gesture.translation.width, gesture.translation.height) >= 4 else { return }
                                preview = DragPreview(area: area, score: WheelInteraction.score(
                                    x: Double(gesture.location.x - center.x), y: Double(gesture.location.y - center.y),
                                    radius: Double(radius), area: area))
                            }
                            .onEnded { gesture in
                                guard hypot(gesture.translation.width, gesture.translation.height) >= 4 else {
                                    select?(area)
                                    return
                                }
                                _ = update(area, WheelInteraction.score(
                                    x: Double(gesture.location.x - center.x), y: Double(gesture.location.y - center.y),
                                    radius: Double(radius), area: area))
                            })
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(localizedFormat("%@ score", area.title))
                        .accessibilityValue(localizedScore(value))
                        .accessibilityHint("Swipe up or down to adjust, or tap the area name to add a reflection.")
                        .accessibilityAdjustableAction { direction in
                            switch direction {
                            case .increment: _ = update(area, min(10, (wheel.score(area) ?? 0) + 1))
                            case .decrement: _ = update(area, max(0, (wheel.score(area) ?? 0) - 1))
                            @unknown default: break
                            }
                        }
                        .accessibilityIdentifier("wheel-handle-\(area.rawValue)")
                        .position(mark)
                    } else if value != nil {
                        Circle().fill(area.color).frame(width: 8, height: 8)
                            .overlay(Circle().stroke(Palette.paper, lineWidth: 2))
                            .position(mark).accessibilityHidden(true)
                    }
                }
            }
            .coordinateSpace(name: "radar")
        }
        .aspectRatio(360.0 / 337.0, contentMode: .fit)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("life-wheel")
    }

    private func score(_ area: Area) -> Int? {
        drag?.area == area ? drag?.score : wheel.score(area)
    }

    private func areaLabel(_ area: Area) -> some View {
        VStack(spacing: 3) {
            Text(area.title).font(.system(.caption2))
            Text(score(area).map(String.init) ?? "—")
                .font(.system(.caption2).weight(.bold)).foregroundStyle(Palette.ink)
        }
        .foregroundStyle(Palette.ink)
        .lineLimit(1).minimumScaleFactor(0.7)
        .frame(width: 68, height: 44)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(area.title)
        .accessibilityValue(localizedScore(score(area)))
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
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        AreaBadge(area: area)
                        Text(localized("Changes saved automatically")).font(.system(.caption)).foregroundStyle(Palette.muted)
                        Spacer()
                    }
                    Text("How do you feel about this area?")
                        .font(.system(.subheadline)).foregroundStyle(Palette.muted)
                    HStack {
                        Button { score = max(0, (score ?? 0) - 1) } label: { stepper("minus") }
                            .accessibilityLabel(localizedFormat("%@ minus one", area.title))
                        Spacer()
                        HStack(alignment: .firstTextBaseline, spacing: 5) {
                            Text(score.map(String.init) ?? "—").font(.system(.largeTitle, design: .serif))
                                .accessibilityIdentifier("editor-score")
                            Text("/ 10").font(.system(.title3)).foregroundStyle(Palette.muted)
                        }
                        Spacer()
                        Button { score = min(10, (score ?? 0) + 1) } label: { stepper("plus") }
                            .accessibilityLabel(localizedFormat("%@ plus one", area.title))
                    }
                    .buttonStyle(.plain)
                    Slider(value: Binding(get: { Double(score ?? 0) }, set: { score = Int($0) }), in: 0...10, step: 1)
                        .accessibilityLabel(localizedFormat("%@ score", area.title))
                        .accessibilityValue(localizedScore(score))
                        .accessibilityIdentifier("score-slider")
                    HStack {
                        Text("0 · Not at all satisfied")
                        Spacer()
                        Text("10 · Very satisfied")
                    }
                    .font(.system(.caption2)).foregroundStyle(Palette.muted)
                    Text("Your reflection").font(.system(.subheadline).weight(.semibold)).padding(.top, 8)
                    TextEditor(text: $note)
                        .scrollContentBackground(.hidden)
                        .font(.system(.body)).padding(8).frame(minHeight: 155)
                        .background(Palette.background, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.line, lineWidth: 1))
                        .accessibilityLabel("Your reflection")
                        .accessibilityIdentifier("area-note")
                    HStack {
                        Text(failed ? localized("Changes could not be saved") : localized("Changes saved automatically"))
                        Spacer()
                        Text("\(note.utf16.count) / 4000")
                    }
                    .font(.system(.caption2)).foregroundStyle(failed ? .red : Palette.muted)
                    if failed {
                        Text(note.utf16.count > 4000 ? localized("Keep your reflection to 4,000 characters or fewer.") :
                             localized("Your edits are still here. Tap Done to try saving again."))
                            .font(.footnote).foregroundStyle(.red)
                    }
                    Button {
                        if persist() { dismiss() }
                    } label: {
                        Text("Done").font(.system(.subheadline).weight(.semibold)).frame(maxWidth: .infinity, minHeight: 36)
                    }
                    .buttonStyle(.borderedProminent).buttonBorderShape(.roundedRectangle(radius: 14))
                    .accessibilityIdentifier("editor-done")
                }
                .padding(24)
            }
            .background(Palette.paper).foregroundStyle(Palette.ink)
            .navigationTitle(area.title)
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(failed)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { if persist() { dismiss() } }
                        .accessibilityIdentifier("editor-toolbar-done")
                }
            }
            .onChange(of: score) { _ in _ = persist() }
            .onChange(of: note) { _ in _ = persist() }
        }
        .presentationDragIndicator(.visible)
    }

    private func stepper(_ symbol: String) -> some View {
        Image(systemName: symbol).font(.system(.title3))
            .frame(width: 47, height: 47).foregroundStyle(Palette.green)
            .background(Palette.pale, in: Circle())
    }

    @discardableResult
    private func persist() -> Bool {
        guard note.utf16.count <= 4000 else { failed = true; return false }
        failed = !save(score, note)
        return !failed
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
        var title: String { self == .replace ? localized("Replace current draft?") : localized("Delete this check-in?") }
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
                        HStack {
                            AreaBadge(area: area)
                            Text(area.title)
                            Spacer()
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
        .toolbar(.visible, for: .navigationBar)
        .background(Palette.background)
        .alert(item: $action) { action in
            Alert(title: Text(action.title),
                  message: Text(action == .replace ? localized("Your current scores and notes will be replaced. History will be kept.") : localized("This check-in and its notes will be removed from history.")),
                  primaryButton: .destructive(Text(action == .replace ? localized("Replace draft") : localized("Delete"))) {
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
                    Label("A little space to come back to yourself.", systemImage: "bell")
                        .foregroundStyle(Palette.green)
                    Text("Choose a daily, weekly, or monthly reminder. Notifications contain no scores or notes.")
                        .font(.footnote).foregroundStyle(Palette.muted)
                }
                Section {
                    Toggle("Enable reminder", isOn: $config.enabled)
                        .accessibilityIdentifier("reminder-enabled")
                    if config.enabled {
                        Picker("Frequency", selection: $config.frequency) {
                            ForEach(ReminderSchedule.Frequency.allCases) { item in Text(item.title).tag(item) }
                        }
                        .accessibilityIdentifier("reminder-frequency")
                        if config.frequency == .weekly {
                            Picker("Day of the week", selection: $config.weekday) {
                                ForEach(Array(AppLanguage.load().calendar.weekdaySymbols.enumerated()), id: \.offset) { index, day in
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
                            .accessibilityIdentifier("reminder-time")
                    }
                }
                if reminders.schedule.enabled, let next = reminders.nextDate {
                    Section("Next scheduled reminder") {
                        Text(next, format: .dateTime.month().day().hour().minute())
                            .accessibilityIdentifier("reminder-next-date")
                    }
                }
                if let failure {
                    Section { Text(failure).foregroundStyle(.red) }
                }
                Section {
                    if !reminders.canNotify {
                        Text("When you save an enabled reminder, iPhone asks for notification permission. If notifications are blocked, enable them in Settings.")
                            .font(.footnote).foregroundStyle(Palette.muted)
                    }
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        Link("Open iPhone Settings", destination: url)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.background)
            .navigationTitle(localized("Reflection reminder"))
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
                                failure = reminders.error ?? localized("Wait for the current update and try again.")
                                reminders.error = nil
                            }
                        }
                    }
                    .disabled(reminders.busy)
                    .accessibilityIdentifier("save-reminder")
                }
            }
        }
    }
}
