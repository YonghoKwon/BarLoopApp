import CoreMIDI
import Foundation
import Observation

enum MIDIAction: String, CaseIterable, Identifiable {
    case togglePlayback
    case previousSection
    case restartLoop
    case nextSection
    var id: String { rawValue }
}

@MainActor
@Observable
final class MIDIManager {
    private(set) var sourceNames: [String] = []
    private(set) var lastNote: UInt8?
    var onAction: ((MIDIAction) -> Void)?
    var mappings: [MIDIAction: UInt8] = [
        .togglePlayback: 36,
        .previousSection: 37,
        .restartLoop: 38,
        .nextSection: 49,
    ]

    private var client = MIDIClientRef()
    private var inputPort = MIDIPortRef()
    private var notificationObserver: NSObjectProtocol?

    func start() {
        guard client == 0 else {
            reconnectSources()
            return
        }
        MIDIClientCreateWithBlock("BarLoop MIDI" as CFString, &client) { [weak self] _ in
            Task { @MainActor in self?.reconnectSources() }
        }
        MIDIInputPortCreateWithBlock(client, "BarLoop Input" as CFString, &inputPort) { [weak self] packets, _ in
            guard let self else { return }
            var packet = packets.pointee.packet
            for _ in 0..<packets.pointee.numPackets {
                let length = Int(packet.length)
                let bytes = withUnsafeBytes(of: packet.data) { Array($0.prefix(length)) }
                self.consume(bytes)
                packet = MIDIPacketNext(&packet).pointee
            }
        }
        reconnectSources()
    }

    func stop() {
        if inputPort != 0 { MIDIPortDispose(inputPort) }
        if client != 0 { MIDIClientDispose(client) }
        inputPort = 0
        client = 0
        sourceNames = []
    }

    func reconnectSources() {
        guard inputPort != 0 else { return }
        var names: [String] = []
        for index in 0..<MIDIGetNumberOfSources() {
            let source = MIDIGetSource(index)
            MIDIPortConnectSource(inputPort, source, nil)
            var name: Unmanaged<CFString>?
            MIDIObjectGetStringProperty(source, kMIDIPropertyDisplayName, &name)
            names.append((name?.takeRetainedValue() as String?) ?? "MIDI \(index + 1)")
        }
        sourceNames = names
    }

    private nonisolated func consume(_ bytes: [UInt8]) {
        var index = 0
        while index + 2 < bytes.count {
            let status = bytes[index] & 0xF0
            if status == 0x90, bytes[index + 2] > 0 {
                let note = bytes[index + 1]
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    lastNote = note
                    if let action = mappings.first(where: { $0.value == note })?.key {
                        onAction?(action)
                    }
                }
            }
            index += 3
        }
    }
}

