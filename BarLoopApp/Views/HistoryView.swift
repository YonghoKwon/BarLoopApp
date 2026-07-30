import BarLoopCore
import Charts
import SwiftData
import SwiftUI

struct HistoryView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \StoredPracticeSession.startedAt, order: .reverse)
    private var storedSessions: [StoredPracticeSession]

    @State private var goalMinutes = 30
    @State private var workMinutes = 20
    @State private var restMinutes = 5
    @State private var coachPhase = CoachPhase.idle
    @State private var coachRemainingSeconds = 0
    @State private var coachTask: Task<Void, Never>?

    private var sessions: [PracticeSession] { storedSessions.map(\.value) }
    private var points: [DailyPracticePoint] {
        PracticeMath.dailySeries(sessions: sessions)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    summary
                    chart
                    coach
                    recent
                }
                .padding()
            }
            .navigationTitle("history.title")
            .onDisappear {
                coachTask?.cancel()
            }
        }
    }

    private var summary: some View {
        PracticeCard("history.week") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                metric("history.sessions", value: "\(weekSessions.count)", icon: "calendar")
                metric("history.time", value: duration(weekSessions.reduce(0) { $0 + $1.activeSeconds }), icon: "clock.fill")
                metric("history.streak", value: "\(PracticeMath.practiceStreak(sessions: sessions))", icon: "flame.fill")
                metric("history.bestBPM", value: "\(weekSessions.compactMap(\.bestBPM).max() ?? 0)", icon: "speedometer")
            }
        }
    }

    private var chart: some View {
        PracticeCard("history.chart") {
            Chart(points) { point in
                BarMark(
                    x: .value("Day", point.date, unit: .day),
                    y: .value("Minutes", Double(point.activeSeconds) / 60)
                )
                .foregroundStyle(BarLoopTheme.cyan.gradient)
                .cornerRadius(5)
            }
            .frame(height: 190)
            .chartYAxis {
                AxisMarks(position: .leading)
            }
        }
    }

    private var coach: some View {
        PracticeCard("coach.title") {
            Stepper("coach.goal \(goalMinutes) min", value: $goalMinutes, in: 5...180, step: 5)
            HStack {
                Stepper("coach.work \(workMinutes)", value: $workMinutes, in: 1...60)
                Stepper("coach.rest \(restMinutes)", value: $restMinutes, in: 1...20)
            }
            ProgressView(
                value: Double(todaySeconds),
                total: Double(goalMinutes * 60)
            )
            .tint(todaySeconds >= goalMinutes * 60 ? .green : BarLoopTheme.orange)
            Text("coach.progress \(duration(todaySeconds)) / \(goalMinutes) min")
                .font(.caption)
                .foregroundStyle(.secondary)
            if coachPhase != .idle {
                HStack {
                    StatusPill(
                        title: coachPhase == .work ? "coach.phase.work" : "coach.phase.rest",
                        color: coachPhase == .work ? BarLoopTheme.orange : BarLoopTheme.cyan
                    )
                    Spacer()
                    Text(clock(coachRemainingSeconds))
                        .font(.title2.monospacedDigit().bold())
                }
            }
            Button(coachPhase == .idle ? "coach.start" : "coach.stop") {
                coachPhase == .idle ? startCoach() : stopCoach(save: true)
            }
            .buttonStyle(.borderedProminent)
            .tint(coachPhase == .idle ? BarLoopTheme.orange : .red)
        }
    }

    private var recent: some View {
        PracticeCard("history.recent") {
            if storedSessions.isEmpty {
                ContentUnavailableView(
                    "history.empty",
                    systemImage: "figure.run",
                    description: Text("history.empty.description")
                )
            } else {
                ForEach(storedSessions.prefix(30)) { stored in
                    let session = stored.value
                    HStack(alignment: .top) {
                        Image(systemName: session.completed ? "checkmark.circle.fill" : "stop.circle.fill")
                            .foregroundStyle(session.completed ? .green : .secondary)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(session.label).font(.headline)
                            Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if !session.note.isEmpty {
                                Text(session.note).font(.caption)
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text(duration(session.activeSeconds))
                                .monospacedDigit()
                            if let bpm = session.bestBPM {
                                Text("\(bpm) BPM")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Button(role: .destructive) {
                            modelContext.delete(stored)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.plain)
                    }
                    Divider()
                }
            }
        }
    }

    private var weekSessions: [PracticeSession] {
        let start = Date.now.addingTimeInterval(-7 * 86_400)
        return sessions.filter { $0.startedAt >= start }
    }

    private var todaySeconds: Int {
        let calendar = Calendar.current
        return sessions.filter { calendar.isDateInToday($0.startedAt) }.reduce(0) { $0 + $1.activeSeconds }
    }

    private func metric(_ title: LocalizedStringKey, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(BarLoopTheme.cyan)
            Text(value)
                .font(.title2.bold())
                .monospacedDigit()
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BarLoopTheme.elevated, in: RoundedRectangle(cornerRadius: 14))
    }

    private func duration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
    }

    private func startCoach() {
        coachTask?.cancel()
        coachPhase = .work
        coachRemainingSeconds = workMinutes * 60
        if environment.metronome.state != .running {
            environment.metronome.start()
        }
        coachTask = Task {
            while coachRemainingSeconds > 0, !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                coachRemainingSeconds -= 1
            }
            guard !Task.isCancelled else { return }
            environment.metronome.stop()
            coachPhase = .rest
            coachRemainingSeconds = restMinutes * 60
            while coachRemainingSeconds > 0, !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                coachRemainingSeconds -= 1
            }
            guard !Task.isCancelled else { return }
            stopCoach(save: true)
        }
    }

    private func stopCoach(save: Bool) {
        coachTask?.cancel()
        coachTask = nil
        environment.metronome.stop()
        if save, coachPhase != .idle {
            let planned = workMinutes * 60
            let active = coachPhase == .work ? max(1, planned - coachRemainingSeconds) : planned
            modelContext.insert(StoredPracticeSession(.init(
                startedAt: Date.now.addingTimeInterval(TimeInterval(-active)),
                endedAt: .now,
                activeSeconds: active,
                label: String(localized: "session.coached"),
                startBPM: environment.metronome.settings.bpm,
                bestBPM: environment.metronome.settings.bpm,
                completed: coachPhase == .rest && coachRemainingSeconds == 0
            )))
        }
        coachPhase = .idle
        coachRemainingSeconds = 0
    }

    private func clock(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

private enum CoachPhase {
    case idle, work, rest
}
