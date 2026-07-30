import BarLoopCore
import SwiftUI

struct BeatGridView: View {
    let beatsPerBar: Int
    let subdivision: Subdivision
    let activeBeat: Int
    let activeSubdivision: Int
    let audible: Bool

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(0..<beatsPerBar, id: \.self) { beat in
                    HStack(spacing: 4) {
                        ForEach(
                            Array(MetronomeMath.countGroup(beatIndex: beat, subdivision: MetronomeMath.visualSubdivision(for: subdivision)).enumerated()),
                            id: \.offset
                        ) { index, token in
                            let isActive = audible && beat == activeBeat &&
                                index == MetronomeMath.visualIndex(playback: subdivision, index: activeSubdivision)
                            Text(token)
                                .font(.caption.monospaced().weight(isActive ? .bold : .regular))
                                .foregroundStyle(isActive ? Color.black : Color.secondary)
                                .frame(width: 27, height: 32)
                                .background(isActive ? BarLoopTheme.cyan : Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 7))
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("beat.grid")
        .accessibilityValue("\(activeBeat + 1)")
    }
}

