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

    private enum Sheet: String, Identifiable {
        case settings, reminders
        var id: String { rawValue }
    }

    var body: some View {
        TabView {
            NavigationStack {
                Group {
                    if store.ready { wheel }
                    else {
                        VStack(spacing: 16) {
                            Text("Saved reflections could not be opened.")
                            Button("Open settings") { sheet = .settings }
                        }
                        .padding()
                    }
                }
                .navigationTitle("Brújula")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItemGroup(placement: .navigationBarTrailing) {
                        Button { sheet = .reminders } label: {
                            Image(systemName: reminders.schedule.enabled ? "bell.badge" : "bell")
                        }
                        .accessibilityLabel("Reminders")
                        Button { sheet = .settings } label: { Image(systemName: "gearshape") }
                            .accessibilityLabel("Settings")
                    }
                }
            }
            .tabItem { Label("My wheel", systemImage: "circle.hexagongrid") }

            NavigationStack { history }
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }

            NavigationStack {
                List(Area.allCases) { item in
                    Button { area = item } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.title).font(.headline)
                            Text(store.state.draft.note(item).isEmpty ? String(localized: "Add a reflection") : store.state.draft.note(item))
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(!store.ready)
                }
                .navigationTitle("Notes")
            }
            .tabItem { Label("Notes", systemImage: "note.text") }
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
                if store.saveCheckIn(title) { notice = String(localized: "Check-in saved.") }
            }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Keep a snapshot of your current scores and notes.") }
        .alert("Restore backup?", isPresented: $restore) {
            Button("Restore", role: .destructive) {
                if let imported, store.commit(imported) { notice = String(localized: "Backup restored.") }
                imported = nil
            }
            Button("Cancel", role: .cancel) { imported = nil }
        } message: { Text("This replaces the scores, notes, and check-ins on this device.") }
        .alert("Clear local data?", isPresented: $reset) {
            Button("Clear data", role: .destructive) {
                Task {
                    let previous = reminders.schedule
                    guard await reminders.save(ReminderSchedule()) else {
                        if reminders.error == nil { notice = String(localized: "Wait for the reminder update to finish and try again.") }
                        return
                    }
                    if store.commit(ReflectionState()) { notice = String(localized: "Local data cleared.") }
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
            VStack(alignment: .leading, spacing: 18) {
                Text("A MOMENT FOR YOURSELF").font(.caption.weight(.bold)).tracking(2).foregroundStyle(Palette.green)
                Text("Your life,\nin perspective.").font(.system(.largeTitle, design: .serif))
                    .accessibilityAddTraits(.isHeader)
                Text("You don’t need a perfect wheel. Just a moment to listen to how you feel.")
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your wheel of life").font(.headline)
                    RadarView(wheel: store.state.draft) { area = $0 }
                    Text("Tap an area to rate it and write a note.").font(.footnote).foregroundStyle(.secondary)
                }
                .padding().background(.background, in: RoundedRectangle(cornerRadius: 20))
                if let average = store.state.draft.average {
                    LabeledContent("Average of rated areas") { Text(average, format: .number.precision(.fractionLength(1))) }
                }
                VStack(spacing: 0) {
                    ForEach(Area.allCases) { item in
                        Button { area = item } label: {
                            HStack {
                                Text(item.title)
                                Spacer()
                                Text(store.state.draft.score(item).map { "\($0)/10" } ?? String(localized: "Not rated")).foregroundStyle(.secondary)
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                            }
                            .frame(minHeight: 48)
                            .padding(.horizontal, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if item != .growth { Divider() }
                    }
                }
                .background(.background, in: RoundedRectangle(cornerRadius: 16))
                Button {
                    saveTitle = ""
                    savingCheckIn = true
                } label: { Text("Save check-in").frame(maxWidth: .infinity, minHeight: 32) }
                    .buttonStyle(.borderedProminent)
                    .disabled(!store.state.draft.complete)
                if !store.state.draft.complete {
                    Text("Rate all eight areas to save a check-in.").font(.footnote).foregroundStyle(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private var history: some View {
        let entries = store.state.history.compactMap { entry in entry.date.map { (entry, $0) } }
            .sorted { $0.1 > $1.1 }
        return List {
            if store.state.history.isEmpty { Text("Your saved check-ins will appear here.").foregroundStyle(.secondary) }
            if entries.count >= 2 {
                Section("Recent trend") {
                    Picker("Area", selection: $trendArea) {
                        Text("Overall average").tag(nil as Area?)
                        ForEach(Area.allCases) { item in Text(item.title).tag(Optional(item)) }
                    }
                    Chart {
                        ForEach(Array(entries.prefix(90).reversed().map { $0.0 })) { entry in
                            if let date = entry.date, let value = trendValue(entry) {
                                LineMark(x: .value("Date", date), y: .value("Score", value))
                                    .symbol(.circle)
                            }
                        }
                    }
                    .chartYScale(domain: 0...10)
                    .frame(height: 145)
                }
            }
            ForEach(entries.map { $0.0 }) { entry in
                NavigationLink {
                    HistoryDetail(entry: entry)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.title).font(.headline)
                        if let date = entry.date { Text(date, format: .dateTime.year().month().day()).foregroundStyle(.secondary) }
                    }
                }
            }
        }
        .navigationTitle("History")
    }

    private func trendValue(_ entry: CheckIn) -> Double? {
        if let trendArea { return entry.wheel.score(trendArea).map(Double.init) }
        return entry.wheel.average
    }

    private var settings: some View {
        NavigationStack {
            Form {
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
        } catch { notice = String(localized: "Could not open the backup. Choose a valid Brújula JSON file under 8 MB.") }
    }
}
