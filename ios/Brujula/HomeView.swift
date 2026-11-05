import SwiftUI
import UniformTypeIdentifiers
import Charts

struct HomeView: View {
    @EnvironmentObject private var store: ReflectionStore
    @EnvironmentObject private var reminders: ReminderStore
    @State private var area: Area?
    @State private var sheet: Sheet?
    @State private var importFile = false
    @State private var exportFile = false
    @State private var backup: BackupDocument?
    @State private var imported: ReflectionState?
    @State private var restore = false
    @State private var reset = false
    @State private var notice: String?
    @State private var saveTitle = ""
    @State private var savingCheckIn = false
    @State private var trendArea: Area?
    @State private var afterSettings: (() -> Void)?
    @State private var tab = Tab.wheel

    private enum Tab: String, CaseIterable {
        case wheel, history, notes
        var title: String { self == .wheel ? "My wheel" : rawValue.capitalized }
        var symbol: String {
            switch self {
            case .wheel: return "chart.pie"
            case .history: return "clock.arrow.circlepath"
            case .notes: return "note.text"
            }
        }
    }

    private enum Sheet: String, Identifiable {
        case settings, reminders
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                if !store.ready {
                    VStack(spacing: 16) {
                        Text("Saved reflections could not be opened.")
                        Button("Open settings") { sheet = .settings }
                    }
                    .padding()
                    .frame(maxHeight: .infinity)
                } else {
                    switch tab {
                    case .wheel: wheel
                    case .history: history
                    case .notes: notes
                    }
                }
            }
            .background(Palette.background)
            .foregroundStyle(Palette.ink)
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom, spacing: 0) { navigation }
        }
        .sheet(item: $area) { item in
            AreaEditor(area: item, wheel: store.state.draft) { score, note in
                store.edit(item, score: score, note: note)
            }
        }
        .sheet(item: $sheet, onDismiss: settingsDismissed) { destination in
            switch destination {
            case .settings: settings
            case .reminders: ReminderEditor(schedule: reminders.schedule)
            }
        }
        .alert("Save check-in", isPresented: $savingCheckIn) {
            TextField("Title (optional)", text: $saveTitle)
            Button("Save") {
                let title = String(decoding: saveTitle.utf16.prefix(80), as: UTF16.self)
                if store.saveCheckIn(title) { notice = "Check-in saved." }
            }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Keep a snapshot of your current scores and notes.") }
        .alert("Restore backup?", isPresented: $restore) {
            Button("Restore", role: .destructive) {
                if let imported, store.commit(imported) { notice = "Backup restored." }
                imported = nil
            }
            Button("Cancel", role: .cancel) { imported = nil }
        } message: { Text("This replaces the scores, notes, and check-ins on this device.") }
        .alert("Clear local data?", isPresented: $reset) {
            Button("Clear data", role: .destructive) {
                Task {
                    let previous = reminders.schedule
                    guard await reminders.save(ReminderSchedule()) else {
                        if reminders.error == nil { notice = "Wait for the reminder update to finish and try again." }
                        return
                    }
                    if store.commit(ReflectionState()) { notice = "Local data cleared." }
                    else if previous.enabled { _ = await reminders.save(previous) }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { Text("This deletes your local scores, notes, and check-ins and turns off reminders. Export a backup first if you want to keep them.") }
        .alert("Brújula", isPresented: messagePresented) {
            Button("OK") { clearMessages() }
        } message: { Text(store.error ?? reminders.error ?? notice ?? "") }
        .fileImporter(isPresented: $importFile, allowedContentTypes: [.json], onCompletion: loadBackup)
        .fileExporter(isPresented: $exportFile, document: backup, contentType: .json,
                      defaultFilename: "brujula-backup") { result in
            if case .failure(let error) = result { notice = error.localizedDescription }
            backup = nil
        }
    }

    private var reminderStatus: String {
        guard reminders.schedule.enabled else { return "Off" }
        return reminders.canNotify ? "On" : "Notifications blocked"
    }

    private var header: some View {
        HStack {
            HStack(spacing: 7) {
                Image(systemName: "safari")
                    .font(.system(size: 30, weight: .ultraLight))
                    .foregroundStyle(Palette.green)
                Text("Brújula").font(.system(size: 29, weight: .semibold, design: .serif))
                Text(".").font(.system(size: 29, design: .serif)).foregroundStyle(Palette.color(0xC78C64))
                    .padding(.leading, -7)
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: 4)
            Button { sheet = .reminders } label: {
                VStack(spacing: 4) {
                    Image(systemName: reminders.schedule.enabled ? "bell.badge" : "bell")
                        .font(.system(size: 21))
                    Text("Reminders").font(.system(size: 9, weight: .semibold))
                }
                .frame(minWidth: 68, minHeight: 50)
                .background(reminders.schedule.enabled ? Palette.pale : .clear,
                            in: RoundedRectangle(cornerRadius: 13))
            }
            .accessibilityLabel("Reflection reminder")
            .accessibilityValue(reminderStatus)
            .accessibilityIdentifier("reminder-shortcut")
            Button { sheet = .settings } label: {
                Image(systemName: "gearshape").font(.system(size: 21)).frame(width: 44, height: 48)
            }
            .accessibilityLabel("Settings")
            .accessibilityIdentifier("settings")
        }
        .buttonStyle(.plain)
        .foregroundStyle(Palette.green)
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .frame(maxWidth: 680)
        .frame(maxWidth: .infinity)
    }

    private var navigation: some View {
        HStack(spacing: 14) {
            ForEach(Tab.allCases, id: \.self) { item in
                Button { tab = item } label: {
                    VStack(spacing: 5) {
                        Image(systemName: item.symbol).font(.system(size: 21))
                        Text(item.title).font(.system(size: 10, weight: tab == item ? .bold : .regular))
                    }
                    .frame(minWidth: 80, minHeight: 51)
                    .foregroundStyle(tab == item ? Palette.green : Palette.muted)
                    .background(tab == item ? Palette.pale : .clear, in: RoundedRectangle(cornerRadius: 13))
                }
                .accessibilityAddTraits(tab == item ? [.isSelected] : [])
                .accessibilityIdentifier("tab-\(item.rawValue)")
            }
        }
        .buttonStyle(.plain)
        .padding(.top, 8)
        .padding(.bottom, 5)
        .frame(maxWidth: .infinity)
        .background(Palette.background)
        .overlay(alignment: .top) { Rectangle().fill(Palette.line).frame(height: 1) }
    }

    private var messagePresented: Binding<Bool> {
        Binding(get: { store.error != nil || reminders.error != nil || notice != nil },
                set: { if !$0 { clearMessages() } })
    }

    private func clearMessages() {
        store.error = nil
        reminders.error = nil
        notice = nil
    }

    private var wheel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(Date.now, format: .dateTime.day().month(.abbreviated).year())
                    .font(.system(size: 11)).foregroundStyle(Palette.muted).padding(.bottom, 14)
                eyebrow("A MOMENT FOR YOURSELF")
                Text("Your life,\nin perspective.").font(.system(size: 41, design: .serif))
                    .tracking(-1.4).lineSpacing(-2).padding(.top, 9).padding(.bottom, 14)
                    .accessibilityAddTraits(.isHeader)
                Text("You don’t need a perfect wheel. Just a moment to listen to how you feel.")
                    .font(.system(size: 13)).lineSpacing(5).foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true).padding(.bottom, 22)
                VStack(alignment: .leading, spacing: 5) {
                    Text("YOUR WHEEL OF LIFE").font(.system(size: 10, weight: .bold)).tracking(1.5)
                        .foregroundStyle(Palette.muted).padding(.horizontal, 10)
                    RadarView(wheel: store.state.draft, select: { area = $0 }, update: { item, score in
                        store.edit(item, score: score, note: store.state.draft.note(item))
                    })
                    Text("Tap an area or drag a point to adjust its score")
                        .font(.system(size: 10)).foregroundStyle(Palette.muted)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 10).padding(.vertical, 18)
                .background(Palette.paper, in: RoundedRectangle(cornerRadius: 22))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(Palette.line, lineWidth: 1))
                HStack(alignment: .top, spacing: 12) {
                    statistic("PERSONAL AVERAGE", value: store.state.draft.average.map {
                        $0.formatted(.number.precision(.fractionLength(1)))
                    } ?? "—", foot: store.state.draft.complete ? "Eight areas, your own perspective" : "Average of rated areas",
                              color: Palette.pale, numeric: true)
                    statistic("A LITTLE MORE CARE", value: lowestArea?.title ?? "—",
                              foot: "A space you can come back to", color: Palette.warm)
                }
                .padding(.top, 14).padding(.bottom, 27)
                HStack(alignment: .firstTextBaseline) {
                    Text("Your eight areas").font(.system(size: 25, design: .serif))
                    Spacer()
                    Text("0–10 · tap to edit").font(.system(size: 10)).foregroundStyle(Palette.muted)
                }
                .padding(.bottom, 12)
                VStack(spacing: 0) {
                    ForEach(Area.allCases) { item in
                        Button { area = item } label: {
                            HStack(spacing: 12) {
                                AreaBadge(area: item)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(item.title).font(.system(size: 13, weight: .semibold))
                                    GeometryReader { geometry in
                                        Capsule().fill(Palette.pale)
                                            .overlay(alignment: .leading) {
                                                Capsule().fill(item.color)
                                                    .frame(width: geometry.size.width * Double(store.state.draft.score(item) ?? 0) / 10)
                                            }
                                    }
                                    .frame(width: 75, height: 4)
                                    Text(store.state.draft.note(item).isEmpty ? "Add a reflection…" : store.state.draft.note(item))
                                        .font(.system(size: 10)).foregroundStyle(Palette.muted).lineLimit(1)
                                }
                                Spacer()
                                Text(store.state.draft.score(item).map(String.init) ?? "—")
                                    .font(.system(size: 24, design: .serif))
                                Image(systemName: "chevron.right").font(.system(size: 12, weight: .light))
                                    .foregroundStyle(Palette.muted)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 15)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(item.title), \(store.state.draft.score(item).map { "\($0) out of 10" } ?? "Not rated")")
                        .accessibilityIdentifier("area-\(item.rawValue)")
                        if item != .growth { Divider().overlay(Palette.line) }
                    }
                }
                .background(Palette.paper, in: RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Palette.line, lineWidth: 1))
                Button {
                    saveTitle = ""
                    savingCheckIn = true
                } label: { Label("Save check-in", systemImage: "plus").font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 36) }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.roundedRectangle(radius: 14))
                    .disabled(!store.state.draft.complete)
                    .accessibilityIdentifier("save-check-in")
                    .padding(.top, 20)
                Text(store.state.draft.complete ? "Changes saved automatically" : "Rate all eight areas to save a check-in.")
                    .font(.system(size: 10)).foregroundStyle(Palette.muted)
                    .frame(maxWidth: .infinity).padding(.top, 12)
                Label("Only on this device. No accounts or connection.", systemImage: "lock")
                    .font(.system(size: 10)).foregroundStyle(Palette.muted)
                    .frame(maxWidth: .infinity).padding(.top, 12)
            }
            .padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 28)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .id(tab)
    }

    private var lowestArea: Area? {
        Area.allCases.filter { store.state.draft.score($0) != nil }
            .min { store.state.draft.score($0)! < store.state.draft.score($1)! }
    }

    private func eyebrow(_ text: String) -> some View {
        HStack(spacing: 7) {
            Circle().fill(Palette.color(0x9AA76D)).frame(width: 6, height: 6)
            Text(text).font(.system(size: 10, weight: .bold)).tracking(2)
        }
        .foregroundStyle(Palette.green)
    }

    private func statistic(_ title: String, value: String, foot: String, color: Color, numeric: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 9, weight: .bold)).tracking(1).foregroundStyle(Palette.muted)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value).font(.system(size: numeric ? 31 : 24, design: .serif))
                    .lineLimit(1).minimumScaleFactor(0.7)
                if numeric { Text("/ 10").font(.system(size: 12)).foregroundStyle(Palette.muted) }
            }
            Text(foot).font(.system(size: 10)).foregroundStyle(Palette.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16).frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
        .background(color, in: RoundedRectangle(cornerRadius: 17))
    }

    private var notes: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                eyebrow("SPACE TO LISTEN TO YOURSELF")
                Text("What’s behind\na number.").font(.system(size: 41, design: .serif)).tracking(-1.4)
                Text("Draft notes are saved as you write. Save a check-in to keep that reflection in your history too.")
                    .font(.system(size: 13)).foregroundStyle(Palette.muted).lineSpacing(5)
                ForEach(Area.allCases) { item in
                    Button { area = item } label: {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                AreaBadge(area: item)
                                Text(item.title).font(.system(size: 13, weight: .semibold))
                                Spacer()
                                Text(store.state.draft.score(item).map(String.init) ?? "—")
                                    .font(.system(size: 22, design: .serif))
                            }
                            Text(store.state.draft.note(item).isEmpty ? "Add a reflection…" : store.state.draft.note(item))
                                .font(.system(size: 13)).foregroundStyle(Palette.muted)
                                .lineSpacing(5).frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .reflectionCard()
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(item.title)
                    .accessibilityValue("\(store.state.draft.score(item).map { "\($0) out of 10" } ?? "Not rated"). \(store.state.draft.note(item).isEmpty ? "Add a reflection" : store.state.draft.note(item))")
                    .accessibilityIdentifier("note-\(item.rawValue)")
                }
            }
            .padding(24).frame(maxWidth: 640).frame(maxWidth: .infinity)
        }
    }

    private var history: some View {
        let entries = store.state.history.compactMap { entry in entry.date.map { (entry, $0) } }
            .sorted { $0.1 > $1.1 }
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                eyebrow("YOUR PATH, AT YOUR PACE")
                Text("Every moment counts.").font(.system(size: 41, design: .serif)).tracking(-1.4)
                Text("See how your priorities change. Your history tells your story, without judging it.")
                    .font(.system(size: 13)).foregroundStyle(Palette.muted).lineSpacing(5)
                if entries.isEmpty {
                    Text("Your saved check-ins will appear here. Save a moment from My wheel.")
                        .font(.system(size: 13)).foregroundStyle(Palette.muted)
                        .frame(maxWidth: .infinity).padding(.vertical, 40)
                }
                if entries.count >= 2 {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Your progress").font(.system(size: 25, design: .serif))
                        Picker("Area", selection: $trendArea) {
                            Text("Overall average").tag(nil as Area?)
                            ForEach(Area.allCases) { item in Text(item.title).tag(Optional(item)) }
                        }
                        Chart {
                            ForEach(Array(entries.prefix(90).reversed().map { $0.0 })) { entry in
                                if let date = entry.date, let value = trendValue(entry) {
                                    LineMark(x: .value("Date", date), y: .value("Score", value))
                                        .symbol(.circle).foregroundStyle(Palette.green)
                                }
                            }
                        }
                        .chartYScale(domain: 0...10).frame(height: 145)
                    }
                    .reflectionCard()
                }
                ForEach(entries.map { $0.0 }) { entry in
                    NavigationLink {
                        HistoryDetail(entry: entry)
                    } label: {
                        VStack(alignment: .leading, spacing: 12) {
                            if let date = entry.date {
                                Text(date, format: .dateTime.year().month().day())
                                    .font(.system(size: 10)).foregroundStyle(Palette.muted)
                            }
                            HStack {
                                Text(entry.title).font(.system(size: 14, weight: .semibold))
                                Spacer()
                                if let average = entry.wheel.average {
                                    Text(average, format: .number.precision(.fractionLength(1)))
                                        .font(.system(size: 30, design: .serif))
                                }
                            }
                            HStack(alignment: .bottom, spacing: 5) {
                                ForEach(Area.allCases) { item in
                                    RoundedRectangle(cornerRadius: 3).fill(item.color)
                                        .frame(height: max(2, CGFloat(entry.wheel.score(item) ?? 0) * 3.5))
                                }
                            }
                            .frame(height: 35, alignment: .bottom)
                        }
                        .reflectionCard()
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(24).frame(maxWidth: 640).frame(maxWidth: .infinity)
        }
    }

    private func trendValue(_ entry: CheckIn) -> Double? {
        if let trendArea { return entry.wheel.score(trendArea).map(Double.init) }
        return entry.wheel.average
    }

    private var settings: some View {
        NavigationStack {
            Form {
                Section("Reminders") {
                    Button { dismissSettings { sheet = .reminders } } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "bell").foregroundStyle(Palette.green)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Reflection reminder").font(.headline)
                                Text(reminderStatus).font(.caption).foregroundStyle(Palette.muted)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption)
                        }
                        .padding(.vertical, 6)
                    }
                    .accessibilityIdentifier("reminder-settings")
                    Text("Choose a daily, weekly, or monthly moment to come back to yourself.")
                        .font(.footnote).foregroundStyle(Palette.muted)
                }
                Section("Privacy") {
                    Text("Your reflections stay on this device. Brújula has no account, ads, or analytics.")
                    NavigationLink("Privacy policy") { privacy }
                }
                Section("Backups") {
                    Button("Export backup") {
                        do {
                            backup = BackupDocument(data: try store.state.encoded())
                            dismissSettings { exportFile = true }
                        } catch { notice = error.localizedDescription }
                    }
                    .disabled(!store.ready)
                    Button("Restore backup") { dismissSettings { importFile = true } }
                    Text("Backups include your notes and are not encrypted by Brújula. They work on iPhone and Android.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section {
                    Button("Clear data and start fresh", role: .destructive) { dismissSettings { reset = true } }
                        .disabled(!store.ready || reminders.busy)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { sheet = nil } } }
        }
    }

    private func dismissSettings(then action: @escaping () -> Void) {
        afterSettings = action
        sheet = nil
    }

    private func settingsDismissed() {
        let action = afterSettings
        afterSettings = nil
        action?()
    }

    private var privacy: some View {
        List {
            Section("Local data") {
                Text("Brújula stores scores, notes, history, and reminder settings in protected files inside the app. These files are excluded from automatic device backups. The app does not collect or send your reflections.")
            }
            Section("Reminders") {
                Text("Reminders are off by default. If you enable one, iOS schedules it locally. Notifications never include scores or notes.")
            }
            Section("Retention and deletion") {
                Text("Use Settings → Clear data and start fresh or remove the app to delete its local data. Exported backups are separate. You choose where to save them and are responsible for deleting them.")
            }
            Section("Contact") {
                Link("Brújula project and support", destination: URL(string: "https://github.com/anderrow/brujula/issues")!)
                Text("Support issues are public. Do not include private notes, scores, or backups.")
            }
        }
        .navigationTitle("Privacy policy")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func loadBackup(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            imported = try ReflectionState.decode(LocalFiles.read(url))
            restore = true
        } catch { notice = "Could not open the backup. Choose a valid Brújula JSON file under 8 MB." }
    }
}
