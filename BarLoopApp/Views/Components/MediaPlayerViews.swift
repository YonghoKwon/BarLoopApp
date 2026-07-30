import AVKit
import SwiftUI
import WebKit

struct LocalVideoPlayerView: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.allowsPictureInPicturePlayback = true
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        controller.updatesNowPlayingInfoCenter = false
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        controller.player = player
    }
}

struct YouTubeWebPlayerView: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ view: WKWebView, context: Context) {}
}

struct AudioArtworkView: View {
    let title: String
    let isPlaying: Bool

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, BarLoopTheme.indigo.opacity(0.5), BarLoopTheme.cyan.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .stroke(BarLoopTheme.cyan.opacity(isPlaying ? 0.9 : 0.35), lineWidth: 2)
                .frame(width: 112, height: 112)
                .overlay {
                    Image(systemName: "waveform")
                        .font(.system(size: 42, weight: .medium))
                        .foregroundStyle(BarLoopTheme.cyan)
                }
            VStack {
                Spacer()
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .foregroundStyle(.white)
                    .padding()
            }
        }
    }
}

