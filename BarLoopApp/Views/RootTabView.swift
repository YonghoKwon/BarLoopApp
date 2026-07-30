import SwiftUI

struct RootTabView: View {
    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        TabView {
            PracticeView(environment: environment)
                .tabItem {
                    Label("tab.practice", systemImage: "repeat")
                }
            MetronomeView()
                .tabItem {
                    Label("tab.metronome", systemImage: "metronome")
                }
            DrumTrainingView()
                .tabItem {
                    Label("tab.training", systemImage: "square.grid.3x3.fill")
                }
            HistoryView()
                .tabItem {
                    Label("tab.history", systemImage: "chart.bar.fill")
                }
            SettingsView()
                .tabItem {
                    Label("tab.settings", systemImage: "gearshape.fill")
                }
        }
        .tint(BarLoopTheme.cyan)
    }
}

