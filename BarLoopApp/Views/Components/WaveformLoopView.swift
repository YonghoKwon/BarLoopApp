import SwiftUI

struct WaveformLoopView: View {
    let samples: [Float]
    let duration: TimeInterval
    let currentTime: TimeInterval
    @Binding var start: TimeInterval
    @Binding var end: TimeInterval
    let onSeek: (TimeInterval) -> Void

    var body: some View {
        VStack(spacing: 10) {
            GeometryReader { proxy in
                let width = proxy.size.width
                let safeDuration = max(0.1, duration)
                ZStack {
                    Canvas { context, size in
                        let values = samples.isEmpty ? Array(repeating: Float(0.25), count: 80) : samples
                        let step = size.width / CGFloat(max(1, values.count))
                        for (index, value) in values.enumerated() {
                            let height = max(2, size.height * CGFloat(value))
                            let x = CGFloat(index) * step + step / 2
                            let rect = CGRect(x: x, y: (size.height - height) / 2, width: max(1, step * 0.55), height: height)
                            context.fill(Path(roundedRect: rect, cornerRadius: 1), with: .color(.secondary.opacity(0.55)))
                        }
                    }
                    Rectangle()
                        .fill(BarLoopTheme.cyan.opacity(0.14))
                        .frame(width: width * CGFloat(max(0, end - start) / safeDuration))
                        .offset(x: width * CGFloat((start + end) / 2 / safeDuration - 0.5))
                    marker(label: "A", x: width * CGFloat(start / safeDuration), color: BarLoopTheme.cyan)
                    marker(label: "B", x: width * CGFloat(end / safeDuration), color: BarLoopTheme.orange)
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 2)
                        .offset(x: width * CGFloat(currentTime / safeDuration - 0.5))
                }
                .contentShape(Rectangle())
                .gesture(SpatialTapGesture().onEnded { value in
                    onSeek(max(0, min(safeDuration, Double(value.location.x / width) * safeDuration)))
                })
            }
            .frame(height: 94)

            VStack(spacing: 6) {
                HStack {
                    Text("loop.a \(format(start))")
                    Slider(value: $start, in: 0...max(0.1, end - 0.1))
                        .tint(BarLoopTheme.cyan)
                }
                HStack {
                    Text("loop.b \(format(end))")
                    Slider(value: $end, in: min(duration, start + 0.1)...max(start + 0.1, duration))
                        .tint(BarLoopTheme.orange)
                }
            }
            .font(.caption.monospacedDigit())
        }
    }

    private func marker(label: String, x: CGFloat, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2.bold())
                .foregroundStyle(.black)
                .frame(width: 22, height: 18)
                .background(color, in: Capsule())
            Rectangle().fill(color).frame(width: 2)
        }
        .offset(x: x - 11)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func format(_ value: TimeInterval) -> String {
        let minutes = Int(max(0, value) / 60)
        return String(format: "%d:%05.2f", minutes, max(0, value) - Double(minutes * 60))
    }
}
