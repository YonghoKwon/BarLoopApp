import BarLoopCore
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.modelContext) private var modelContext
    @Query private var sessions: [StoredPracticeSession]
    @Query private var sections: [StoredPracticeSection]
    @Query private var patterns: [StoredDrumPattern]
    @Query private var routines: [StoredPracticeRoutine]

    @State private var exportDocument: BarLoopBackupDocument?
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var backupMessage: String?

    var body: some View {
        @Bindable var settings = environment.settings
        NavigationStack {
            Form {
                Section("settings.appearance") {
                    Picker("settings.theme", selection: $settings.appearance) {
                        Text("appearance.system").tag(AppAppearance.system)
                        Text("appearance.light").tag(AppAppearance.light)
                        Text("appearance.dark").tag(AppAppearance.dark)
                    }
                    Toggle("settings.keepAwake", isOn: $settings.keepAwake)
                }

                Section("settings.audio") {
                    LabeledContent("settings.route", value: environment.audioSession.currentRoute)
                    Button("metronome.test") {
                        environment.metronome.playTestClick()
                    }
                    if case let .failed(message) = environment.audioSession.state {
                        Text(message).foregroundStyle(.red)
                    }
                }

                mediaSection
                midiSection
                backupSection

                Section("settings.privacySupport") {
                    Link(destination: URL(string: "https://yonghokwon.github.io/BarLoopApp/privacy.html")!) {
                        Label("settings.privacy", systemImage: "hand.raised.fill")
                    }
                    Link(destination: URL(string: "https://yonghokwon.github.io/BarLoopApp/support.html")!) {
                        Label("settings.support", systemImage: "questionmark.circle.fill")
                    }
                    Link(destination: URL(string: "https://github.com/YonghoKwon/BarLoopApp")!) {
                        Label("settings.sourceCode", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                    Text("settings.youtubeDisclosure")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("settings.about") {
                    LabeledContent("settings.version", value: appVersion)
                    LabeledContent("settings.storage", value: ByteCountFormatter.string(
                        fromByteCount: environment.mediaLibrary.totalBytes,
                        countStyle: .file
                    ))
                    Text("settings.localFirst")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("settings.title")
            .fileExporter(
                isPresented: $showExporter,
                document: exportDocument,
                contentType: BarLoopBackupDocument.readableContentTypes[0],
                defaultFilename: "BarLoop-\(Date.now.formatted(.iso8601.year().month().day())).barloop.json"
            ) { result in
                backupMessage = switch result {
                case .success: String(localized: "backup.export.success")
                case let .failure(error): error.localizedDescription
                }
            }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: BarLoopBackupDocument.readableContentTypes,
                allowsMultipleSelection: false
            ) { result in
                guard case let .success(urls) = result, let url = urls.first else { return }
                importBackup(url)
            }
            .alert("backup.title", isPresented: Binding(
                get: { backupMessage != nil },
                set: { if !$0 { backupMessage = nil } }
            )) {
                Button("common.ok", role: .cancel) {}
            } message: {
                Text(backupMessage ?? "")
            }
        }
    }

    private var mediaSection: some View {
        Section("settings.media") {
            if environment.mediaLibrary.items.isEmpty {
                Text("settings.media.empty")
                    .foregroundStyle(.secondary)
            }
            ForEach(environment.mediaLibrary.items) { item in
                HStack {
                    Image(systemName: item.kind == .video ? "film.fill" : "music.note")
                        .foregroundStyle(BarLoopTheme.cyan)
                    VStack(alignment: .leading) {
                        Text(item.fileName).lineLimit(1)
                        Text(ByteCountFormatter.string(fromByteCount: item.byteCount, countStyle: .file))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(role: .destructive) {
                        environment.mediaLibrary.remove(item)
                    } label: {
                        Image(systemName: "trash")
                    }
                }
            }
        }
    }

    private var midiSection: some View {
        Section("settings.midi") {
            if environment.midi.sourceNames.isEmpty {
                Text("midi.none")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(environment.midi.sourceNames, id: \.self) {
                    Label($0, systemImage: "cable.connector")
                }
            }
            ForEach(MIDIAction.allCases) { action in
                Stepper(
                    "\(midiActionLabel(action)): \(environment.midi.mappings[action] ?? 0)",
                    value: midiBinding(action),
                    in: 0...127
                )
            }
            if let note = environment.midi.lastNote {
                LabeledContent("midi.lastNote", value: "\(note)")
            }
            Button("midi.refresh") {
                environment.midi.reconnectSources()
            }
        }
    }

    private var backupSection: some View {
        Section("backup.title") {
            Button {
                exportDocument = BarLoopBackupDocument(backup: makeBackup())
                showExporter = true
            } label: {
                Label("backup.export", systemImage: "square.and.arrow.up")
            }
            Button {
                showImporter = true
            } label: {
                Label("backup.import", systemImage: "square.and.arrow.down")
            }
            Text("backup.notice")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func midiBinding(_ action: MIDIAction) -> Binding<Int> {
        Binding(
            get: { Int(environment.midi.mappings[action] ?? 0) },
            set: { environment.midi.mappings[action] = UInt8(clamping: $0) }
        )
    }

    private func midiActionLabel(_ action: MIDIAction) -> String {
        String(localized: "midi.action.\(action.rawValue)")
    }

    private func makeBackup() -> BarLoopBackup {
        .init(
            practiceSettings: environment.settings.practice,
            metronomeSettings: environment.settings.metronome,
            tempoTrainerSettings: environment.settings.tempoTrainer,
            sections: sections.compactMap(\.value),
            sessions: sessions.map(\.value),
            patterns: patterns.compactMap(\.value),
            routines: routines.compactMap(\.value)
        )
    }

    private func importBackup(_ url: URL) {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        do {
            let backup = try BackupCodec.decode(Data(contentsOf: url))
            sessions.forEach(modelContext.delete)
            sections.forEach(modelContext.delete)
            patterns.forEach(modelContext.delete)
            routines.forEach(modelContext.delete)
            backup.sessions.forEach { modelContext.insert(StoredPracticeSession($0)) }
            backup.sections.forEach { modelContext.insert(StoredPracticeSection($0)) }
            backup.patterns.forEach { modelContext.insert(StoredDrumPattern($0)) }
            backup.routines.forEach { modelContext.insert(StoredPracticeRoutine($0)) }
            environment.settings.apply(backup)
            try modelContext.save()
            backupMessage = String(localized: "backup.import.success")
        } catch {
            backupMessage = error.localizedDescription
        }
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }
}
