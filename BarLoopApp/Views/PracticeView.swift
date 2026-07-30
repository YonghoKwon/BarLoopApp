import BarLoopCore
import SwiftData
import SwiftUI

struct PracticeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \StoredPracticeSection.name) private var storedSections: [StoredPracticeSection]

    @State private var controller: PracticeController
    @State private var showImporter = false
    @State private var loopStart: TimeInterval = 0
    @State private var loopEnd: TimeInterval = 8
    @State private var selectedBarStart = 0
    @State private var selectedBarEnd = 0
    @State private var sectionName = ""
    @State private var sectionNote = ""
    @State private var sectionTargetRepeats = 4
    @State private var sessionStartedAt: Date?

    init(environment: AppEnvironment) {
        _controller = State(initialValue: PracticeController(environment: environment))
    }

    var body: some View {
        @Bindable var controller = controller
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    sourceCard
                    playerCard
                    transportCard
                    loopCard
                    tempoCard
                    trainerCard
                    sectionCard
                }
                .padding()
            }
            .navigationTitle("practice.title")
            .background(Color(uiColor: .systemBackground))
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: LocalMediaLibrary.supportedTypes,
                allowsMultipleSelection: false
            ) { result in
                guard case let .success(urls) = result, let url = urls.first else { return }
                Task {
                    if let item = await controller.environment.mediaLibrary.importFile(from: url) {
                        await controller.select(item)
                    }
                }
            }
            .alert("notice.title", isPresented: Binding(
                get: { controller.notice != nil },
                set: { if !$0 { controller.notice = nil } }
            )) {
                Button("common.ok", role: .cancel) {}
            } message: {
                Text(controller.notice ?? "")
            }
        }
    }

    private var sourceCard: some View {
        PracticeCard("practice.source") {
            Picker("practice.source", selection: $controller.sourceMode) {
                Label("source.local", systemImage: "folder.fill").tag(PracticeSourceMode.local)
                Label("source.youtube", systemImage: "play.rectangle.fill").tag(PracticeSourceMode.youtube)
            }
            .pickerStyle(.segmented)

            if controller.sourceMode == .local {
                HStack {
                    Menu {
                        ForEach(controller.environment.mediaLibrary.items) { item in
                            Button(item.fileName) {
                                Task { await controller.select(item) }
                            }
                        }
                    } label: {
                        Label(
                            controller.selectedLocalItem?.fileName ?? String(localized: "source.choose"),
                            systemImage: "music.note.list"
                        )
                        .lineLimit(1)
                    }
                    .buttonStyle(.bordered)
                    Spacer()
                    Button {
                        showImporter = true
                    } label: {
                        Label("source.import", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(BarLoopTheme.cyan)
                    .foregroundStyle(.black)
                }
            } else {
                HStack {
                    TextField("youtube.placeholder", text: $controller.youtubeInput)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                    Button("source.load") {
                        controller.loadYouTube()
                    }
                    .buttonStyle(.borderedProminent)
                }
                Text("youtube.precision.notice")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var playerCard: some View {
        PracticeCard {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black)
                if controller.sourceMode == .youtube, controller.youtubeVideoID != nil {
                    YouTubeWebPlayerView(webView: controller.environment.youtubePlayer.webView)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                } else if let item = controller.selectedLocalItem {
                    if item.kind == .video {
                        LocalVideoPlayerView(player: controller.environment.localPlayer.player)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    } else {
                        AudioArtworkView(title: item.fileName, isPlaying: controller.state == .playing)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                } else {
                    ContentUnavailableView(
                        "player.empty.title",
                        systemImage: "waveform",
                        description: Text("player.empty.description")
                    )
                    .foregroundStyle(.white)
                }
            }
            .aspectRatio(16 / 9, contentMode: .fit)
            .overlay(alignment: .topTrailing) {
                StatusPill(
                    title: controller.sourceMode == .youtube ? "source.online" : "source.onDevice",
                    color: controller.sourceMode == .youtube ? .red : .green
                )
                .padding(10)
            }
        }
    }

    private var transportCard: some View {
        PracticeCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(time(controller.currentTime))
                        .font(.title2.monospacedDigit().bold())
                    Text("/ \(time(controller.duration))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    controller.seek(to: max(0, controller.currentTime - 5))
                } label: {
                    Image(systemName: "gobackward.5").font(.title2)
                }
                .buttonStyle(.plain)
                PrimaryTransportButton(isPlaying: controller.state == .playing) {
                    if controller.state == .playing {
                        controller.pause()
                        saveSession(completed: false)
                    } else {
                        sessionStartedAt = .now
                        controller.play()
                    }
                }
                Button {
                    controller.seek(to: min(controller.duration, controller.currentTime + 5))
                } label: {
                    Image(systemName: "goforward.5").font(.title2)
                }
                .buttonStyle(.plain)
                Spacer()
                VStack(alignment: .trailing) {
                    Text("loop.count")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(controller.loopCount)")
                        .font(.title2.monospacedDigit().bold())
                }
            }
        }
    }

    private var loopCard: some View {
        PracticeCard("practice.loop") {
            Toggle("loop.enabled", isOn: binding(\.loopEnabled))
            WaveformLoopView(
                samples: controller.waveform,
                duration: max(0.1, controller.duration),
                currentTime: controller.currentTime,
                start: $loopStart,
                end: $loopEnd
            ) { controller.seek(to: $0) }
            .onChange(of: loopStart) { _, _ in controller.setTimeLoop(start: loopStart, end: loopEnd) }
            .onChange(of: loopEnd) { _, _ in controller.setTimeLoop(start: loopStart, end: loopEnd) }

            HStack {
                Button("loop.setA") {
                    loopStart = min(controller.currentTime, loopEnd - 0.1)
                }
                Button("loop.restart") { controller.restartLoop() }
                Button("loop.setB") {
                    loopEnd = max(controller.currentTime, loopStart + 0.1)
                }
            }
            .buttonStyle(.bordered)

            if !controller.bars.isEmpty {
                HStack {
                    Stepper("loop.barStart \(selectedBarStart + 1)", value: $selectedBarStart, in: 0...max(0, controller.bars.count - 1))
                    Stepper("loop.barEnd \(selectedBarEnd + 1)", value: $selectedBarEnd, in: selectedBarStart...max(selectedBarStart, controller.bars.count - 1))
                }
                .font(.caption)
                Button("loop.applyBars") {
                    controller.setBarLoop(start: selectedBarStart, end: selectedBarEnd)
                }
                .buttonStyle(.bordered)
            }

            HStack {
                Button("loop.quick.3plus1") { controller.quickLoop(grooveBars: 3) }
                Button("loop.quick.7plus1") { controller.quickLoop(grooveBars: 7) }
            }
            .buttonStyle(.bordered)
        }
    }

    private var tempoCard: some View {
        PracticeCard("practice.tempo") {
            HStack {
                Text("\(controller.settings.bpm)")
                    .font(.system(size: 38, weight: .black, design: .rounded))
                    .monospacedDigit()
                Text("BPM").foregroundStyle(.secondary)
                Spacer()
                Button("tempo.tap") { controller.tapTempo() }
                    .buttonStyle(.borderedProminent)
                    .tint(BarLoopTheme.orange)
            }
            Stepper("tempo.bpm", value: bpmBinding, in: 20...400)
            Stepper("tempo.beats \(controller.settings.beatsPerBar)", value: beatsBinding, in: 2...12)
            HStack {
                Text("tempo.speed")
                Slider(value: speedBinding, in: 0.5...2, step: 0.05)
                Text("\(controller.settings.playbackRate, specifier: "%.2f")×")
                    .monospacedDigit()
            }
            Toggle("tempo.pitch", isOn: binding(\.preservePitch))
            Toggle("practice.metronomeAlong", isOn: binding(\.metronomeEnabled))
            Picker("practice.countIn", selection: binding(\.countInBars)) {
                Text("countIn.off").tag(0)
                Text("countIn.one").tag(1)
                Text("countIn.two").tag(2)
                Text("countIn.four").tag(4)
            }
            Stepper("practice.preRoll \(controller.settings.preRollBeats)", value: binding(\.preRollBeats), in: 0...24)
            HStack {
                Text("practice.mediaVolume")
                Slider(value: binding(\.mediaVolume), in: 0...1)
            }
            HStack {
                Text("practice.clickVolume")
                Slider(value: binding(\.metronomeVolume), in: 0...1)
            }
            HStack {
                Text("practice.syncOffset")
                Slider(
                    value: Binding(
                        get: { Double(controller.settings.syncOffsetMilliseconds) },
                        set: {
                            var value = controller.settings
                            value.syncOffsetMilliseconds = Int($0.rounded())
                            controller.settings = value
                        }
                    ),
                    in: -200...200,
                    step: 5
                )
                Text("\(controller.settings.syncOffsetMilliseconds) ms")
                    .font(.caption.monospacedDigit())
            }
        }
    }

    private var trainerCard: some View {
        PracticeCard("trainer.title") {
            Toggle("trainer.enabled", isOn: trainerBinding(\.enabled))
            if controller.trainerSettings.enabled {
                Stepper(
                    "trainer.start \(controller.trainerSettings.startBPM)",
                    value: trainerBinding(\.startBPM),
                    in: 20...400
                )
                Stepper(
                    "trainer.target \(controller.trainerSettings.targetBPM)",
                    value: trainerBinding(\.targetBPM),
                    in: controller.trainerSettings.startBPM...400
                )
                Stepper(
                    "trainer.step \(controller.trainerSettings.stepBPM)",
                    value: trainerBinding(\.stepBPM),
                    in: 1...20
                )
                Stepper(
                    "trainer.repeats \(controller.trainerSettings.repeatsPerStep)",
                    value: trainerBinding(\.repeatsPerStep),
                    in: 1...32
                )
                Stepper(
                    "trainer.rest \(controller.trainerSettings.restSeconds)",
                    value: trainerBinding(\.restSeconds),
                    in: 0...60
                )
                if let bpm = controller.trainerCurrentBPM {
                    LabeledContent("trainer.current", value: "\(bpm) BPM · \(controller.trainerRepeatAtStep)/\(controller.trainerSettings.repeatsPerStep)")
                }
            }
        }
    }

    private var sectionCard: some View {
        PracticeCard("practice.sections") {
            HStack {
                TextField("section.name", text: $sectionName)
                    .textFieldStyle(.roundedBorder)
                Button("section.save") {
                    let name = sectionName.isEmpty ? String(localized: "section.defaultName") : sectionName
                    let mediaKey = activeMediaKey
                    guard !mediaKey.isEmpty else { return }
                    modelContext.insert(StoredPracticeSection(.init(
                        mediaKey: mediaKey,
                        name: name,
                        loop: controller.loop,
                        note: sectionNote,
                        targetRepeats: sectionTargetRepeats
                    )))
                    sectionName = ""
                    sectionNote = ""
                }
                .buttonStyle(.borderedProminent)
            }
            TextField("section.note", text: $sectionNote, axis: .vertical)
                .textFieldStyle(.roundedBorder)
            Stepper("section.target \(sectionTargetRepeats)", value: $sectionTargetRepeats, in: 1...100)
            ForEach(storedSections.filter { $0.mediaKey == activeMediaKey }) { stored in
                if let value = stored.value {
                    Button {
                        controller.loop = value.loop
                    } label: {
                        HStack {
                            Image(systemName: "bookmark.fill")
                            VStack(alignment: .leading) {
                                Text(value.name)
                                Text(value.note).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("×\(value.targetRepeats)").font(.caption.monospacedDigit())
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var activeMediaKey: String {
        if let item = controller.selectedLocalItem { return item.source.stableKey }
        if let id = controller.youtubeVideoID { return MediaSource.youtube(videoID: id).stableKey }
        return ""
    }

    private func binding<T>(_ keyPath: WritableKeyPath<PracticeSettings, T>) -> Binding<T> {
        Binding(
            get: { controller.settings[keyPath: keyPath] },
            set: {
                var settings = controller.settings
                settings[keyPath: keyPath] = $0
                controller.settings = settings
            }
        )
    }

    private var bpmBinding: Binding<Int> { binding(\.bpm) }
    private var beatsBinding: Binding<Int> { binding(\.beatsPerBar) }
    private var speedBinding: Binding<Double> { binding(\.playbackRate) }

    private func trainerBinding<T>(_ keyPath: WritableKeyPath<TempoTrainerSettings, T>) -> Binding<T> {
        Binding(
            get: { controller.trainerSettings[keyPath: keyPath] },
            set: {
                var value = controller.trainerSettings
                value[keyPath: keyPath] = $0
                value.startBPM = PracticeMath.clampBPM(Double(value.startBPM))
                value.targetBPM = max(value.startBPM, PracticeMath.clampBPM(Double(value.targetBPM)))
                controller.trainerSettings = value
            }
        )
    }

    private func saveSession(completed: Bool) {
        guard let started = sessionStartedAt else { return }
        let ended = Date.now
        let seconds = max(1, Int(ended.timeIntervalSince(started)))
        modelContext.insert(StoredPracticeSession(.init(
            startedAt: started,
            endedAt: ended,
            activeSeconds: seconds,
            label: controller.selectedLocalItem?.fileName ?? String(localized: "session.mediaPractice"),
            startBPM: controller.settings.bpm,
            bestBPM: controller.settings.bpm,
            completed: completed
        )))
        sessionStartedAt = nil
    }

    private func time(_ value: TimeInterval) -> String {
        PracticeMath.formatTime(value)
    }
}
