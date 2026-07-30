import Foundation

public enum PlaybackSessionAudioBridge {
    public static func makeNearSilentWAV(
        sampleRate: Int,
        duration: TimeInterval
    ) -> Data {
        let safeRate = max(1, sampleRate)
        let sampleCount = max(1, Int((Double(safeRate) * max(0, duration)).rounded()))
        let dataSize = sampleCount * MemoryLayout<Int16>.size
        var data = Data()
        data.reserveCapacity(44 + dataSize)

        data.appendASCII("RIFF")
        data.appendLittleEndian(UInt32(36 + dataSize))
        data.appendASCII("WAVE")
        data.appendASCII("fmt ")
        data.appendLittleEndian(UInt32(16))
        data.appendLittleEndian(UInt16(1))
        data.appendLittleEndian(UInt16(1))
        data.appendLittleEndian(UInt32(safeRate))
        data.appendLittleEndian(UInt32(safeRate * MemoryLayout<Int16>.size))
        data.appendLittleEndian(UInt16(MemoryLayout<Int16>.size))
        data.appendLittleEndian(UInt16(16))
        data.appendASCII("data")
        data.appendLittleEndian(UInt32(dataSize))

        for index in 0..<sampleCount {
            data.appendLittleEndian(index.isMultiple(of: 2) ? Int16(1) : Int16(-1))
        }
        return data
    }
}

private extension Data {
    mutating func appendASCII(_ value: String) {
        append(contentsOf: value.utf8)
    }

    mutating func appendLittleEndian<T: FixedWidthInteger>(_ value: T) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { append(contentsOf: $0) }
    }
}
