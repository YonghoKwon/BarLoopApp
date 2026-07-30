import BarLoopCore
import SwiftData
import SwiftUI

struct MetronomeView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.modelContext) private var modelContext
    @State private var bpmDraft = "120"
    @State private var tapTimes: [TimeInterval] = []
    @State private var practiceMinutes = 10
    @State private var remainingSeconds = 0
    @State private var timerTask: Task<Void, Never>?
    @State private var sessionStartedAt: Date?
    @State private var rudiment = "Single Stroke"

    var body: some View {
        @Bindable var engine = environment.metronome
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    hero
                    controls
                    soundAndFeel
                    gapAndTrainer
                    timerCard
                }
                .padding()
            }
            .navigationTitle("metronome.title")
            .onAppear {
                environment.metronome.drumPattern = nil
                environment.metronome.movingAccentStep = nil
                environment.metronome.settings = environment.settings.metronome
                bpmDraft = String(environment.metronome.settings.bpm)
            }
            .onChange(of: engine.settings) { _, value in
                environment.settings.metronome = value
            }
            .onDisappear {
                timerTask?.cancel()
            }
        }
    }

    private var hero: some View {
        PracticeCard {
            VStack(spacing: 20) {
                HStack {
                    StatusPill(
                        title: environment.metronome.state == .running ? "status.running" : "status.ready",
                        color: environment.metronome.state == .running ? .green : BarLoopTheme.cyan
                    )
                    Spacer()
                    Text(environment.audioSession.currentRoute)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(environment.metronome.settings.bpm)")
                        .font(.system(size: 68, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text("BPM")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }

                BeatGridView(
                    beatsPerBar: environment.metronome.settings.beatsPerBar,
                    subdivision: environment.metronome.settings.subdivision,
                    activeBeat: environment.metronome.tick.beatInBar,
                    activeSubdivision: environment.metronome.tick.subdivisionInBeat,
                    audible: environment.metronome.tick.audible
                )

                HStack(spacing: 26) {
                    Button {
                        updateBPM(environment.metronome.settings.bpm - 1)
                    } label: {
                        Image(systemName: "minus").frame(width: 44, height: 44)
                    }
                    .buttonStyle(.bordered)

                    PrimaryTransportButton(isPlaying: environment.metronome.state == .running) {
                        toggleMetronome()
                    }

                    Button {
                        updateBPM(environment.metronome.settings.bpm + 1)
                    } label: {
                        Image(systemName: "plus").frame(width: 44, height: 44)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private var controls: some View {
        PracticeCard("metronome.tempoMeter") {
            HStack {
                TextField("BPM", text: $bpmDraft)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 100)
                    .onChange(of: bpmDraft) { _, value in
                        let normalized = PracticeMath.normalizeBPMText(value)
                        if normalized != value { bpmDraft = normalized }
                    }
                    .onSubmit {
                        updateBPM(PracticeMath.parseBPMText(bpmDraft, fallback: environment.metronome.settings.bpm))
                    }
                Button("tempo.tap") { tapTempo() }
                    .buttonStyle(.borderedProminent)
                    .tint(BarLoopTheme.orange)
                Spacer()
                Button("metronome.test") { environment.metronome.playTestClick() }
                    .buttonStyle(.bordered)
            }

            Stepper(
                "tempo.beats \(environment.metronome.settings.beatsPerBar)",
                value: binding(\.beatsPerBar),
                in: 2...12
            )

            Picker("metronome.subdivision", selection: binding(\.subdivision)) {
                Text("subdivision.quarter").tag(Subdivision.quarter)
                Text("subdivision.eighth").tag(Subdivision.eighth)
                Text("subdivision.triplet").tag(Subdivision.triplet)
                Text("subdivision.sixteenth").tag(Subdivision.sixteenth)
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 8) {
                Text("metronome.accents")
                    .font(.subheadline.weight(.semibold))
                HStack {
                    ForEach(0..<environment.metronome.settings.beatsPerBar, id: \.self) { beat in
                        Button {
                            var value = environment.metronome.settings
                            normalizeAccents(&value)
                            value.accents[beat].toggle()
                            environment.metronome.settings = value
                        } label: {
                            Text("\(beat + 1)")
                                .frame(maxWidth: .infinity, minHeight: 34)
                                .background(
                                    accentEnabled(beat) ? BarLoopTheme.orange : Color.primary.opacity(0.07),
                                    in: RoundedRectangle(cornerRadius: 8)
                                )
                                .foregroundStyle(accentEnabled(beat) ? .black : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Picker("metronome.countMode", selection: countModeBinding) {
                Text("count.click").tag(CountMode.click)
                Text("count.voice").tag(CountMode.voice)
                Text("count.both").tag(CountMode.both)
            }
            .onChange(of: environment.settings.countMode) { _, mode in
                environment.metronome.countMode = mode
            }
        }
    }

    private var soundAndFeel: some View {
        PracticeCard("metronome.soundFeel") {
            Picker("metronome.sound", selection: binding(\.sound)) {
                ForEach(ClickSound.allCases) { sound in
                    Text("sound.\(sound.rawValue)").tag(sound)
                }
            }
            Picker("metronome.accentSound", selection: binding(\.accentSound)) {
                ForEach(ClickSound.allCases) { sound in
                    Text("sound.\(sound.rawValue)").tag(sound)
                }
            }
            volumeRow("metronome.mainVolume", value: binding(\.volume))
            volumeRow("metronome.accentVolume", value: binding(\.accentVolume))
            volumeRow("metronome.subdivisionVolume", value: binding(\.subdivisionVolume))
            VStack(alignment: .leading) {
                HStack {
                    Text("metronome.swing")
                    Spacer()
                    Text("\(Int(environment.metronome.settings.swing * 100))%")
                        .monospacedDigit()
                }
                Slider(value: binding(\.swing), in: 0.5...0.75, step: 0.01)
                    .tint(BarLoopTheme.indigo)
                HStack {
                    Text("swing.straight")
                    Spacer()
                    Text("swing.heavy")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var gapAndTrainer: some View {
        PracticeCard("metronome.training") {
            Toggle("gap.enabled", isOn: binding(\.gapEnabled))
            if environment.metronome.settings.gapEnabled {
                Stepper(
                    "gap.play \(environment.metronome.settings.gapPlayBars)",
                    value: binding(\.gapPlayBars),
                    in: 1...16
                )
                Stepper(
                    "gap.mute \(environment.metronome.settings.gapMuteBars)",
                    value: binding(\.gapMuteBars),
                    in: 1...16
                )
            }
            Stepper(
                "trainer.everyBars \(environment.metronome.settings.autoTempoBars)",
                value: binding(\.autoTempoBars),
                in: 0...32
            )
            Stepper(
                "trainer.step \(environment.metronome.settings.autoTempoStep)",
                value: binding(\.autoTempoStep),
                in: 1...20
            )
            Picker("metronome.rudiment", selection: $rudiment) {
                ForEach(["Single Stroke", "Double Stroke", "Paradiddle", "Six Stroke Roll"], id: \.self) {
                    Text($0).tag($0)
                }
            }
            Text(rudimentPattern)
                .font(.title3.monospaced().bold())
                .frame(maxWidth: .infinity)
                .padding(10)
                .background(BarLoopTheme.elevated, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private var timerCard: some View {
        PracticeCard("practice.timer") {
            Picker("practice.duration", selection: $practiceMinutes) {
                ForEach([5, 10, 15, 20, 30], id: \.self) {
                    Text("\($0) min").tag($0)
                }
            }
            .pickerStyle(.segmented)
            HStack {
                Text(remainingSeconds > 0 ? durationText(remainingSeconds) : "\(practiceMinutes):00")
                    .font(.largeTitle.monospacedDigit().bold())
                Spacer()
                Button(remainingSeconds > 0 ? "timer.cancel" : "timer.start") {
                    remainingSeconds > 0 ? cancelTimer() : startTimer()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private func binding<T>(_ keyPath: WritableKeyPath<MetronomeSettings, T>) -> Binding<T> {
        Binding(
            get: { environment.metronome.settings[keyPath: keyPath] },
            set: {
                var value = environment.metronome.settings
                value[keyPath: keyPath] = $0
                normalizeAccents(&value)
                environment.metronome.settings = value
            }
        )
    }

    private var countModeBinding: Binding<CountMode> {
        Binding(
            get: { environment.settings.countMode },
            set: {
                environment.settings.countMode = $0
                environment.metronome.countMode = $0
            }
        )
    }

    private func updateBPM(_ bpm: Int) {
        var value = environment.metronome.settings
        value.bpm = PracticeMath.clampBPM(Double(bpm))
        environment.metronome.settings = value
        bpmDraft = String(value.bpm)
    }

    private func tapTempo() {
        let now = ProcessInfo.processInfo.systemUptime
        if let last = tapTimes.last, now - last > 2 { tapTimes.removeAll() }
        tapTimes.append(now)
        tapTimes = Array(tapTimes.suffix(8))
        guard tapTimes.count > 1 else { return }
        let intervals = zip(tapTimes.dropFirst(), tapTimes).map { $0.0 - $0.1 }
        updateBPM(Int((60 / (intervals.reduce(0, +) / Double(intervals.count))).rounded()))
    }

    private func toggleMetronome() {
        if environment.metronome.state == .running {
            environment.metronome.stop()
            saveSession(completed: false)
        } else {
            sessionStartedAt = .now
            environment.metronome.countMode = environment.settings.countMode
            environment.metronome.start()
        }
    }

    private func normalizeAccents(_ value: inout MetronomeSettings) {
        value.beatsPerBar = max(2, min(12, value.beatsPerBar))
        value.accents = (0..<value.beatsPerBar).map { index in
            value.accents.indices.contains(index) ? value.accents[index] : index == 0
        }
    }

    private func accentEnabled(_ beat: Int) -> Bool {
        environment.metronome.settings.accents.indices.contains(beat)
            ? environment.metronome.settings.accents[beat]
            : beat == 0
    }

    private func volumeRow(_ title: LocalizedStringKey, value: Binding<Double>) -> some View {
        HStack {
            Text(title)
            Slider(value: value, in: 0...1)
            Text("\(Int(value.wrappedValue * 100))")
                .font(.caption.monospacedDigit())
                .frame(width: 28)
        }
    }

    private var rudimentPattern: String {
        switch rudiment {
        case "Double Stroke": "R R L L"
        case "Paradiddle": "R L R R  L R L L"
        case "Six Stroke Roll": "R L L R R L"
        default: "R L R L"
        }
    }

    private func startTimer() {
        remainingSeconds = practiceMinutes * 60
        if environment.metronome.state != .running { toggleMetronome() }
        timerTask?.cancel()
        timerTask = Task {
            while remainingSeconds > 0, !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                remainingSeconds -= 1
            }
            if !Task.isCancelled {
                environment.metronome.stop()
                saveSession(completed: true)
            }
        }
    }

    private func cancelTimer() {
        timerTask?.cancel()
        timerTask = nil
        remainingSeconds = 0
        saveSession(completed: false)
    }

    private func saveSession(completed: Bool) {
        guard let started = sessionStartedAt else { return }
        let ended = Date.now
        modelContext.insert(StoredPracticeSession(.init(
            startedAt: started,
            endedAt: ended,
            activeSeconds: max(1, Int(ended.timeIntervalSince(started))),
            label: String(localized: "session.metronome"),
            startBPM: environment.metronome.settings.bpm,
            bestBPM: environment.metronome.settings.bpm,
            completed: completed
        )))
        sessionStartedAt = nil
    }

    private func durationText(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}
