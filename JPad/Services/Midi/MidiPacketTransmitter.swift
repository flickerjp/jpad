import CoreMIDI
import Foundation

enum MidiPacketTransmitter {
    private static let packetListSize = 256
    private static let eventListSize = 256

    @discardableResult
    static func received(
        _ message: [UInt8],
        on source: MIDIEndpointRef,
        preferEventList: Bool
    ) -> OSStatus {
        guard source != 0, !message.isEmpty else { return errSecParam }

        var lastStatus: OSStatus = errSecParam

        if preferEventList {
            if let status = sendViaEventList(message, on: source) {
                if status == noErr { return noErr }
                lastStatus = status
            }
            if let status = sendViaPacketList(message, on: source) {
                if status == noErr { return noErr }
                lastStatus = status
            }
        } else {
            if let status = sendViaPacketList(message, on: source) {
                if status == noErr { return noErr }
                lastStatus = status
            }
            if let status = sendViaEventList(message, on: source) {
                if status == noErr { return noErr }
                lastStatus = status
            }
        }

        return lastStatus
    }

    @discardableResult
    static func send(
        _ message: [UInt8],
        to destination: MIDIEndpointRef,
        via outputPort: MIDIPortRef
    ) -> OSStatus {
        guard destination != 0, outputPort != 0, !message.isEmpty else { return errSecParam }
        return withPacketList(for: message) { packetList in
            MIDISend(outputPort, destination, packetList)
        } ?? errSecParam
    }

    private static func sendViaPacketList(_ message: [UInt8], on source: MIDIEndpointRef) -> OSStatus? {
        withPacketList(for: message) { MIDIReceived(source, $0) }
    }

    private static func sendViaEventList(_ message: [UInt8], on source: MIDIEndpointRef) -> OSStatus? {
        withEventList(for: message) { MIDIReceivedEventList(source, $0) }
    }

    private static func withPacketList(
        for message: [UInt8],
        action: (UnsafeMutablePointer<MIDIPacketList>) -> OSStatus
    ) -> OSStatus? {
        let rawPointer = UnsafeMutableRawPointer.allocate(
            byteCount: packetListSize,
            alignment: MemoryLayout<MIDIPacketList>.alignment
        )
        defer { rawPointer.deallocate() }

        let packetList = rawPointer.assumingMemoryBound(to: MIDIPacketList.self)
        let timestamp = mach_absolute_time()
        var packet = MIDIPacketListInit(packetList)

        var didAdd = false
        message.withUnsafeBufferPointer { bytes in
            guard let baseAddress = bytes.baseAddress else { return }
            let nextPacket = MIDIPacketListAdd(
                packetList,
                packetListSize,
                packet,
                timestamp,
                bytes.count,
                baseAddress
            )
            guard nextPacket != nil else { return }
            packet = nextPacket
            didAdd = true
        }

        guard didAdd, packetList.pointee.numPackets > 0 else { return nil }
        return action(packetList)
    }

    private static func withEventList(
        for message: [UInt8],
        action: (UnsafeMutablePointer<MIDIEventList>) -> OSStatus
    ) -> OSStatus? {
        guard let umpWord = makeMIDI1UPWord(from: message) else { return nil }

        let rawPointer = UnsafeMutableRawPointer.allocate(
            byteCount: eventListSize,
            alignment: MemoryLayout<MIDIEventList>.alignment
        )
        defer { rawPointer.deallocate() }

        let eventList = rawPointer.assumingMemoryBound(to: MIDIEventList.self)
        let packet = MIDIEventListInit(eventList, MIDIProtocolID(rawValue: 1)!)

        var word = umpWord
        let status = withUnsafePointer(to: &word) { pointer -> OSStatus? in
            pointer.withMemoryRebound(to: UInt32.self, capacity: 1) { rebound in
                let nextPacket = MIDIEventListAdd(
                    eventList,
                    eventListSize,
                    packet,
                    mach_absolute_time(),
                    1,
                    rebound
                )
                guard nextPacket != nil else { return nil }
                return action(eventList)
            }
        }

        return status
    }

    private static func makeMIDI1UPWord(from message: [UInt8]) -> MIDIMessage_32? {
        guard message.count >= 3 else { return nil }

        let status = message[0] & 0xF0
        let channel = message[0] & 0x0F
        let data1 = message[1]
        let data2 = message[2]

        switch status {
        case 0x80:
            return MIDI1UPNoteOff(0, channel, data1, data2)
        case 0x90:
            return MIDI1UPNoteOn(0, channel, data1, data2)
        case 0xB0:
            return MIDI1UPControlChange(0, channel, data1, data2)
        default:
            return nil
        }
    }
}
