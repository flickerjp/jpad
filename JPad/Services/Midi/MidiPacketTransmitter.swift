import CoreMIDI
import Foundation

enum MidiPacketTransmitter {
    struct ReceivedReport {
        let status: OSStatus
        let packetStatus: OSStatus?
        let eventStatus: OSStatus?
        let usedEventList: Bool?
    }

    private static let packetListSize = 2048
    private static let eventListSize = 2048

    @discardableResult
    static func received(
        _ message: [UInt8],
        on source: MIDIEndpointRef,
        preferEventList: Bool
    ) -> OSStatus {
        receivedReport(message, on: source, preferEventList: preferEventList).status
    }

    static func receivedReport(
        _ message: [UInt8],
        on source: MIDIEndpointRef,
        preferEventList: Bool
    ) -> ReceivedReport {
        receivedReport([message], on: source, preferEventList: preferEventList)
    }

    static func receivedReport(
        _ messages: [[UInt8]],
        on source: MIDIEndpointRef,
        preferEventList: Bool
    ) -> ReceivedReport {
        let messages = messages.filter { !$0.isEmpty }
        guard source != 0, !messages.isEmpty else {
            return ReceivedReport(status: errSecParam, packetStatus: nil, eventStatus: nil, usedEventList: nil)
        }

        var lastStatus: OSStatus = errSecParam
        var packetStatus: OSStatus?
        var eventStatus: OSStatus?

        if preferEventList {
            if let status = sendViaEventList(messages, on: source) {
                eventStatus = status
                if status == noErr {
                    return ReceivedReport(status: noErr, packetStatus: packetStatus, eventStatus: eventStatus, usedEventList: true)
                }
                lastStatus = status
            }
            if let status = sendViaPacketList(messages, on: source) {
                packetStatus = status
                if status == noErr {
                    return ReceivedReport(status: noErr, packetStatus: packetStatus, eventStatus: eventStatus, usedEventList: false)
                }
                lastStatus = status
            }
        } else {
            if let status = sendViaPacketList(messages, on: source) {
                packetStatus = status
                if status == noErr {
                    return ReceivedReport(status: noErr, packetStatus: packetStatus, eventStatus: eventStatus, usedEventList: false)
                }
                lastStatus = status
            }
            if let status = sendViaEventList(messages, on: source) {
                eventStatus = status
                if status == noErr {
                    return ReceivedReport(status: noErr, packetStatus: packetStatus, eventStatus: eventStatus, usedEventList: true)
                }
                lastStatus = status
            }
        }

        return ReceivedReport(status: lastStatus, packetStatus: packetStatus, eventStatus: eventStatus, usedEventList: nil)
    }

    @discardableResult
    static func send(
        _ message: [UInt8],
        to destination: MIDIEndpointRef,
        via outputPort: MIDIPortRef
    ) -> OSStatus {
        send([message], to: destination, via: outputPort)
    }

    @discardableResult
    static func send(
        _ messages: [[UInt8]],
        to destination: MIDIEndpointRef,
        via outputPort: MIDIPortRef
    ) -> OSStatus {
        let messages = messages.filter { !$0.isEmpty }
        guard destination != 0, outputPort != 0, !messages.isEmpty else { return errSecParam }
        return withPacketList(for: messages) { packetList in
            MIDISend(outputPort, destination, packetList)
        } ?? errSecParam
    }

    private static func sendViaPacketList(_ message: [UInt8], on source: MIDIEndpointRef) -> OSStatus? {
        sendViaPacketList([message], on: source)
    }

    private static func sendViaPacketList(_ messages: [[UInt8]], on source: MIDIEndpointRef) -> OSStatus? {
        withPacketList(for: messages) { MIDIReceived(source, $0) }
    }

    private static func sendViaEventList(_ message: [UInt8], on source: MIDIEndpointRef) -> OSStatus? {
        sendViaEventList([message], on: source)
    }

    private static func sendViaEventList(_ messages: [[UInt8]], on source: MIDIEndpointRef) -> OSStatus? {
        withEventList(for: messages) { MIDIReceivedEventList(source, $0) }
    }

    private static func withPacketList(
        for message: [UInt8],
        action: (UnsafeMutablePointer<MIDIPacketList>) -> OSStatus
    ) -> OSStatus? {
        withPacketList(for: [message], action: action)
    }

    private static func withPacketList(
        for messages: [[UInt8]],
        action: (UnsafeMutablePointer<MIDIPacketList>) -> OSStatus
    ) -> OSStatus? {
        let messages = messages.filter { !$0.isEmpty }
        guard !messages.isEmpty else { return nil }

        let rawPointer = UnsafeMutableRawPointer.allocate(
            byteCount: packetListSize,
            alignment: MemoryLayout<MIDIPacketList>.alignment
        )
        defer { rawPointer.deallocate() }

        let packetList = rawPointer.assumingMemoryBound(to: MIDIPacketList.self)
        let timestamp = mach_absolute_time()
        var packet = MIDIPacketListInit(packetList)

        var didAdd = false
        for message in messages {
            let added = message.withUnsafeBufferPointer { bytes -> Bool in
                guard let baseAddress = bytes.baseAddress else { return false }
                let nextPacket = MIDIPacketListAdd(
                    packetList,
                    packetListSize,
                    packet,
                    timestamp,
                    bytes.count,
                    baseAddress
                )
                packet = nextPacket
                return true
            }
            guard added else { return nil }
            didAdd = true
        }

        guard didAdd, packetList.pointee.numPackets > 0 else { return nil }
        return action(packetList)
    }

    private static func withEventList(
        for message: [UInt8],
        action: (UnsafeMutablePointer<MIDIEventList>) -> OSStatus
    ) -> OSStatus? {
        withEventList(for: [message], action: action)
    }

    private static func withEventList(
        for messages: [[UInt8]],
        action: (UnsafeMutablePointer<MIDIEventList>) -> OSStatus
    ) -> OSStatus? {
        let words = messages.compactMap(makeMIDI1UPWord)
        guard words.count == messages.filter({ !$0.isEmpty }).count, !words.isEmpty else { return nil }

        let rawPointer = UnsafeMutableRawPointer.allocate(
            byteCount: eventListSize,
            alignment: MemoryLayout<MIDIEventList>.alignment
        )
        defer { rawPointer.deallocate() }

        let eventList = rawPointer.assumingMemoryBound(to: MIDIEventList.self)
        var packet = MIDIEventListInit(eventList, MIDIProtocolID(rawValue: 1)!)
        let timestamp = mach_absolute_time()

        for var word in words {
            let added = withUnsafePointer(to: &word) { pointer -> Bool in
                pointer.withMemoryRebound(to: UInt32.self, capacity: 1) { rebound in
                    let nextPacket = MIDIEventListAdd(
                        eventList,
                        eventListSize,
                        packet,
                        timestamp,
                    1,
                    rebound
                )
                    packet = nextPacket
                    return true
                }
            }
            guard added else { return nil }
        }

        return action(eventList)
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
