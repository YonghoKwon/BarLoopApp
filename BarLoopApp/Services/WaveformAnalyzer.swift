import AVFoundation
import Foundation

enum WaveformAnalyzer {
    static func analyze(url: URL, samples: Int = 240) async throws -> [Float] {
        let asset = AVURLAsset(url: url)
        guard let track = try await asset.loadTracks(withMediaType: .audio).first else { return [] }
        let reader = try AVAssetReader(asset: asset)
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsNonInterleaved: false,
        ]
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: settings)
        guard reader.canAdd(output) else { return [] }
        reader.add(output)
        reader.startReading()

        var absoluteValues: [Float] = []
        while let buffer = output.copyNextSampleBuffer(),
              let block = CMSampleBufferGetDataBuffer(buffer) {
            let length = CMBlockBufferGetDataLength(block)
            var data = Data(count: length)
            data.withUnsafeMutableBytes { pointer in
                guard let base = pointer.baseAddress else { return }
                CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: length, destination: base)
            }
            data.withUnsafeBytes { pointer in
                for value in pointer.bindMemory(to: Float.self) where value.isFinite {
                    absoluteValues.append(abs(value))
                }
            }
        }
        guard !absoluteValues.isEmpty else { return [] }
        let bucket = max(1, absoluteValues.count / max(1, samples))
        let peaks = stride(from: 0, to: absoluteValues.count, by: bucket).prefix(samples).map { index in
            absoluteValues[index..<min(absoluteValues.count, index + bucket)].max() ?? 0
        }
        let maximum = peaks.max() ?? 1
        return peaks.map { maximum > 0 ? $0 / maximum : 0 }
    }
}

