import BarLoopCore
import SwiftData
import SwiftUI

struct DrumTrainingView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.modelContext) private var modelContext
    @Query private var storedPatterns: [StoredDrumPattern]
    @Query private var storedRoutines: [StoredPracticeRoutine]

    @State private var pattern = DrumLibrary.custom
    @State private var selectedPresetID = "basic-rock"
    @State private var movingAccentEnabled = false
    @State private var accentMovement = AccentMovement.forward
    @State private var movingAccent = 0
    @State private var routine = DrumLibrary.defaultRoutine
    @State private var activeRoutineStep = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    patternChooser
                    sequencer
                    trainer
                    routineCard
                }
                .padding()
            }
            .navigationTitle("training.title")
            .onAppear {
                if let stored = storedPatterns.first?.value { pattern = stored }
                if let stored = storedRoutines.first?.value { routine = stored }
            }
        }
    }

    private var patternChooser: some View {
        PracticeCard("training.pattern") {
            Picker("training.preset", selection: $selectedPresetID) {
                ForEach(DrumLibrary.presets) { preset in
                    Text(patternName(preset.id)).tag(preset.id)
                }
                Text("pattern.custom").tag("custom")
            }
            .onChange(of: selectedPresetID) { _, id in
                if id == "custom" {
                    pattern = storedPatterns.first?.value ?? DrumLibrary.custom
                } else if let preset = DrumLibrary.presets.first(where: { $0.id == id }) {
                    pattern = preset
                }
                syncMetronome()
            }
            Stepper("tempo.beats \(pattern.beatsPerBar)", value: beatsBinding, in: 2...12)
            HStack {
                Label("\(pattern.stepCount) steps", systemImage: "square.grid.4x3.fill")
                Spacer()
                Text("\(Int(pattern.swing * 100))% swing")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            Text(pattern.detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var sequencer: some View {
        PracticeCard("training.sequencer") {
            ScrollView(.horizontal, showsIndicators: true) {
                Grid(horizontalSpacing: 5, verticalSpacing: 7) {
                    GridRow {
                        Text("")
                        ForEach(0..<pattern.stepCount, id: \.self) { step in
                            Text(stepLabel(step))
                                .font(.caption2.monospaced())
                                .foregroundStyle(step.isMultiple(of: 4) ? .primary : .secondary)
                                .frame(width: 27)
                        }
                    }
                    ForEach(DrumInstrument.allCases) { instrument in
                        GridRow {
                            Text(instrumentLabel(instrument))
                                .font(.caption.bold())
                                .frame(width: 35, alignment: .leading)
                            ForEach(0..<pattern.stepCount, id: \.self) { step in
                                Button {
                                    pattern.cycle(instrument: instrument, step: step)
                                    selectedPresetID = "custom"
                                } label: {
                                    let level = pattern.steps[instrument]?[step] ?? .off
                                    Circle()
                                        .fill(cellColor(level, active: movingAccentEnabled && movingAccent == step))
                                        .frame(width: 24, height: 24)
                                        .overlay {
                                            if level == .accent {
                                                Circle().stroke(Color.white.opacity(0.8), lineWidth: 2).padding(3)
                                            }
                                        }
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("\(instrumentLabel(instrument)) \(step + 1)")
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            HStack {
                Button("pattern.save") {
                    let custom = pattern
                    if let existing = storedPatterns.first(where: { $0.id == custom.id }) {
                        existing.data = (try? JSONEncoder().encode(custom)) ?? Data()
                    } else {
                        modelContext.insert(StoredDrumPattern(custom))
                    }
                }
                .buttonStyle(.borderedProminent)
                Button("pattern.clear") {
                    pattern = DrumPattern(
                        id: "custom",
                        name: "My Pattern",
                        detail: "Empty custom pattern",
                        beatsPerBar: pattern.beatsPerBar,
                        steps: [:]
                    )
                    selectedPresetID = "custom"
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var trainer: some View {
        PracticeCard("training.accentTrainer") {
            Toggle("training.movingAccent", isOn: $movingAccentEnabled)
            Picker("training.movement", selection: $accentMovement) {
                Text("movement.forward").tag(AccentMovement.forward)
                Text("movement.random").tag(AccentMovement.random)
            }
            .pickerStyle(.segmented)
            HStack {
                Text("training.activeStep")
                Spacer()
                Text("\(movingAccent + 1)")
                    .font(.title3.monospacedDigit().bold())
                Button("training.next") {
                    movingAccent = DrumLibrary.nextAccent(
                        current: movingAccent,
                        mode: accentMovement,
                        totalSteps: pattern.stepCount
                    )
                }
                .buttonStyle(.bordered)
            }
            Button(environment.metronome.state == .running ? "transport.stop" : "training.start") {
                if environment.metronome.state == .running {
                    environment.metronome.stop()
                } else {
                    syncMetronome()
                    environment.metronome.start()
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(environment.metronome.state == .running ? .red : BarLoopTheme.cyan)
        }
    }

    private var routineCard: some View {
        PracticeCard("training.routine") {
            ForEach(Array(routine.steps.enumerated()), id: \.element.id) { index, step in
                Button {
                    activeRoutineStep = index
                    var settings = environment.metronome.settings
                    settings.bpm = step.bpm
                    if let selected = DrumLibrary.presets.first(where: { $0.id == step.patternID }) {
                        pattern = selected
                        selectedPresetID = selected.id
                        settings.beatsPerBar = selected.beatsPerBar
                    }
                    environment.metronome.settings = settings
                } label: {
                    HStack {
                        Text("\(index + 1)")
                            .font(.caption.bold())
                            .frame(width: 28, height: 28)
                            .background(index == activeRoutineStep ? BarLoopTheme.cyan : Color.primary.opacity(0.08), in: Circle())
                            .foregroundStyle(index == activeRoutineStep ? .black : .primary)
                        VStack(alignment: .leading) {
                            Text(step.name)
                            Text("\(step.bpm) BPM · \(step.bars) bars")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if step.accentTrainer {
                            Image(systemName: "scope").foregroundStyle(BarLoopTheme.orange)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            Button("routine.save") {
                if let stored = storedRoutines.first {
                    stored.data = (try? JSONEncoder().encode(routine)) ?? Data()
                } else {
                    modelContext.insert(StoredPracticeRoutine(routine))
                }
            }
            .buttonStyle(.bordered)
        }
    }

    private var beatsBinding: Binding<Int> {
        Binding(
            get: { pattern.beatsPerBar },
            set: {
                pattern.resize(beats: $0)
                selectedPresetID = "custom"
                movingAccent = min(movingAccent, pattern.stepCount - 1)
                syncMetronome()
            }
        )
    }

    private func syncMetronome() {
        var settings = environment.metronome.settings
        settings.beatsPerBar = pattern.beatsPerBar
        settings.subdivision = .sixteenth
        settings.swing = pattern.swing
        settings.accents = (0..<pattern.beatsPerBar).map { $0 == 0 }
        environment.metronome.settings = settings
        environment.metronome.drumPattern = pattern
        environment.metronome.movingAccentStep = movingAccentEnabled ? movingAccent : nil
    }

    private func patternName(_ id: String) -> LocalizedStringKey {
        LocalizedStringKey("pattern.\(id)")
    }

    private func instrumentLabel(_ instrument: DrumInstrument) -> String {
        switch instrument {
        case .crash: "CR"
        case .ride: "RD"
        case .hihat: "HH"
        case .rackTom: "ST"
        case .midTom: "MT"
        case .floorTom: "FT"
        case .snare: "SN"
        case .kick: "BD"
        }
    }

    private func stepLabel(_ step: Int) -> String {
        ["\(step / 4 + 1)", "e", "&", "a"][step % 4]
    }

    private func cellColor(_ level: DrumStepLevel, active: Bool) -> Color {
        if active { return BarLoopTheme.orange }
        switch level {
        case .off: Color.primary.opacity(0.08)
        case .normal: BarLoopTheme.indigo.opacity(0.75)
        case .accent: BarLoopTheme.cyan
        }
    }
}
