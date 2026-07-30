import BarLoopCore
import Foundation
import Observation
import WebKit

@MainActor
@Observable
final class YouTubePlayerController: NSObject, MediaPlaybackControlling {
    private(set) var state: PlaybackState = .idle
    private(set) var currentTime: TimeInterval = 0
    private(set) var duration: TimeInterval = 0
    var rate: Double = 1 {
        didSet { evaluate("player && player.setPlaybackRate(\(rate));") }
    }
    var volume: Double = 0.85 {
        didSet { evaluate("player && player.setVolume(\(Int(max(0, min(1, volume)) * 100)));") }
    }
    private(set) var videoID: String?

    let webView: WKWebView

    override init() {
        let controller = WKUserContentController()
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = [.all]
        configuration.websiteDataStore = .default()
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        controller.add(WeakScriptMessageHandler(target: self), name: "barloop")
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
    }

    func load(videoID: String) {
        guard PracticeMath.extractYouTubeID(videoID) == videoID else {
            state = .failed(String(localized: "youtube.error.invalid"))
            return
        }
        self.videoID = videoID
        state = .loading
        currentTime = 0
        duration = 0
        webView.loadHTMLString(Self.html(videoID: videoID), baseURL: URL(string: "https://www.youtube-nocookie.com"))
    }

    func play() {
        evaluate("player && player.playVideo();")
    }

    func pause() {
        evaluate("player && player.pauseVideo();")
    }

    func seek(to seconds: TimeInterval) {
        let target = max(0, seconds)
        evaluate("player && player.seekTo(\(target), true);")
        currentTime = target
    }

    private func evaluate(_ javascript: String) {
        webView.evaluateJavaScript(javascript)
    }

    private static func html(videoID: String) -> String {
        """
        <!doctype html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1">
          <style>
            html,body,#player { margin:0; width:100%; height:100%; background:#071018; overflow:hidden; }
          </style>
        </head>
        <body>
          <div id="player"></div>
          <script>
            let player;
            const send = (type, value) => window.webkit.messageHandlers.barloop.postMessage({type, value});
            window.onYouTubeIframeAPIReady = () => {
              player = new YT.Player('player', {
                videoId: '\(videoID)',
                width: '100%',
                height: '100%',
                playerVars: {
                  playsinline: 1,
                  rel: 0,
                  modestbranding: 1,
                  origin: 'https://www.youtube-nocookie.com'
                },
                events: {
                  onReady: e => {
                    send('ready', e.target.getDuration());
                    e.target.setVolume(\(Int(volume * 100)));
                    e.target.setPlaybackRate(\(rate));
                  },
                  onStateChange: e => send('state', e.data),
                  onError: e => send('error', e.data)
                }
              });
            };
            const script = document.createElement('script');
            script.src = 'https://www.youtube.com/iframe_api';
            document.head.appendChild(script);
            setInterval(() => {
              if (player && player.getCurrentTime) {
                send('time', {current: player.getCurrentTime(), duration: player.getDuration()});
              }
            }, 100);
          </script>
        </body>
        </html>
        """
    }
}

private final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    weak var target: WKScriptMessageHandler?

    init(target: WKScriptMessageHandler) {
        self.target = target
    }

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        target?.userContentController(userContentController, didReceive: message)
    }
}

extension YouTubePlayerController: WKScriptMessageHandler {
    nonisolated func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard let payload = message.body as? [String: Any],
              let type = payload["type"] as? String else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            switch type {
            case "ready":
                duration = payload["value"] as? Double ?? 0
                state = .ready
            case "state":
                let code = payload["value"] as? Int ?? -1
                state = switch code {
                case 0: .ended
                case 1: .playing
                case 2: .paused
                case 3: .loading
                case 5: .ready
                default: state
                }
            case "time":
                guard let value = payload["value"] as? [String: Any] else { return }
                currentTime = value["current"] as? Double ?? currentTime
                duration = value["duration"] as? Double ?? duration
            case "error":
                let code = payload["value"] as? Int ?? 0
                state = .failed(String(localized: "youtube.error.playback \(code)"))
            default:
                break
            }
        }
    }
}
