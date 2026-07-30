import SwiftUI

enum BarLoopTheme {
    static let cyan = Color(red: 0.20, green: 0.87, blue: 0.94)
    static let orange = Color(red: 1.0, green: 0.55, blue: 0.20)
    static let indigo = Color(red: 0.42, green: 0.48, blue: 1.0)
    static let panel = Color(uiColor: .secondarySystemBackground)
    static let elevated = Color(uiColor: .tertiarySystemBackground)
}

struct PracticeCard<Content: View>: View {
    let title: LocalizedStringKey?
    @ViewBuilder var content: Content

    init(_ title: LocalizedStringKey? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let title {
                Text(title)
                    .font(.headline)
            }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BarLoopTheme.panel, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.primary.opacity(0.06))
        }
    }
}

struct StatusPill: View {
    let title: LocalizedStringKey
    var color: Color = BarLoopTheme.cyan

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .foregroundStyle(color)
            .background(color.opacity(0.13), in: Capsule())
    }
}

struct PrimaryTransportButton: View {
    let isPlaying: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                .font(.title2.weight(.bold))
                .frame(width: 62, height: 62)
                .foregroundStyle(.black)
                .background(BarLoopTheme.cyan, in: Circle())
        }
        .accessibilityLabel(isPlaying ? Text("transport.pause") : Text("transport.play"))
        .buttonStyle(.plain)
    }
}

