import CoreMIDI
import Foundation

enum MidiMessageParser {
    private static let maxPacketsPerList = 64
    private static let maxNotesPerCallback = 32
    private static let umpMIDI1ChannelVoiceType: UInt32 = 0x02

    static func noteOnNumbers(in eventList: UnsafePointer<MIDIEventList>) -> [UInt8] {
        var found = Set<UInt8>()
        let packetCount = min(max(0, Int(eventList.pointee.numPackets)), maxPacketsPerList)
        guard packetCount > 0 else { return [] }

        withUnsafePointer(to: eventList.pointee.packet) { firstPacket in
            var current = firstPacket
            for packetIndex in 0..<packetCount {
                let packet = current.pointee
                let wordCount = min(max(0, Int(packet.wordCount)), 16)
                guard wordCount > 0 else {
                    if packetIndex + 1 < packetCount {
                        current = UnsafePointer(MIDIEventPacketNext(current))
                    }
                    continue
                }

                withUnsafePointer(to: packet.words) { wordsPointer in
                    wordsPointer.withMemoryRebound(to: UInt32.self, capacity: wordCount) { rebound in
                        for wordIndex in 0..<wordCount {
                            if let note = noteNumberFromUMPWord(rebound[wordIndex]) {
                                found.insert(note)
                            }
                        }
                    }
                }

                if found.count >= maxNotesPerCallback { return }
                if packetIndex + 1 < packetCount {
                    current = UnsafePointer(MIDIEventPacketNext(current))
                }
            }
        }

        return found.sorted()
    }

    static func noteOnNumbers(in packetList: UnsafePointer<MIDIPacketList>) -> [UInt8] {
        var found = Set<UInt8>()
        let packetCount = min(max(0, Int(packetList.pointee.numPackets)), maxPacketsPerList)
        guard packetCount > 0 else { return [] }

        withUnsafePointer(to: packetList.pointee.packet) { firstPacket in
            var current = firstPacket
            for packetIndex in 0..<packetCount {
                let packet = current.pointee
                for note in noteOnNumbers(in: payloadBytes(from: packet)) where note <= 127 {
                    found.insert(note)
                    if found.count >= maxNotesPerCallback { return }
                }
                if packetIndex + 1 < packetCount {
                    current = UnsafePointer(MIDIPacketNext(current))
                }
            }
        }

        return found.sorted()
    }

    static func noteOnNumbers(in bytes: [UInt8]) -> [UInt8] {
        guard !bytes.isEmpty else { return [] }

        let notes: [UInt8]
        if bytes.contains(0xF0) {
            notes = noteOnNumbersFromSerialMIDI(bytes)
        } else if looksLikeUSBMIDI(bytes) {
            notes = noteOnNumbersFromUSBMIDI(bytes)
        } else {
            notes = noteOnNumbersFromVoiceMessages(bytes)
        }

        return Array(notes.filter { $0 <= 127 }.prefix(maxNotesPerCallback))
    }

    private static func looksLikeUSBMIDI(_ bytes: [UInt8]) -> Bool {
        guard bytes.count >= 4, bytes.count % 4 == 0 else { return false }
        for index in stride(from: 0, to: min(bytes.count, 16), by: 4) {
            let cin = bytes[index] & 0x0F
            if cin > 0x0F { return false }
        }
        return true
    }

    private static func noteOnNumbersFromUSBMIDI(_ bytes: [UInt8]) -> [UInt8] {
        var notes: [UInt8] = []
        var index = 0

        while index + 4 <= bytes.count {
            let codeIndex = bytes[index] & 0x0F
            let data1 = bytes[index + 1]
            let data2 = bytes[index + 2]
            let data3 = bytes[index + 3]

            switch codeIndex {
            case 0x9:
                if data3 > 0, data2 <= 127 {
                    notes.append(data2)
                }
            case 0x4, 0x5, 0x6, 0x7:
                break
            default:
                break
            }

            index += 4
        }

        return notes
    }

    /// CoreMIDI がバイト列を展開済みで渡す場合（CK 系で Port1 に多い）
    private static func noteOnNumbersFromVoiceMessages(_ bytes: [UInt8]) -> [UInt8] {
        var notes: [UInt8] = []
        var index = 0

        while index < bytes.count {
            let byte = bytes[index]

            if byte & 0xF0 == 0x90 {
                guard index + 2 < bytes.count else { break }
                let note = bytes[index + 1]
                let velocity = bytes[index + 2]
                if velocity > 0, note <= 127 {
                    notes.append(note)
                }
                index += 3
                continue
            }

            if byte & 0xF0 == 0x80 {
                guard index + 2 < bytes.count else { break }
                index += 3
                continue
            }

            if byte >= 0xF8 {
                index += 1
                continue
            }

            if byte >= 0xF0 {
                index += 1
                continue
            }

            index += 1
        }

        return notes
    }

    private static func noteOnNumbersFromSerialMIDI(_ bytes: [UInt8]) -> [UInt8] {
        var notes: [UInt8] = []
        var index = 0
        var runningStatus: UInt8?

        while index < bytes.count {
            let byte = bytes[index]

            if byte == 0xF0 {
                index += 1
                while index < bytes.count, bytes[index] != 0xF7 {
                    index += 1
                }
                if index < bytes.count {
                    index += 1
                }
                runningStatus = nil
                continue
            }

            if byte >= 0xF8 {
                index += 1
                continue
            }

            if byte >= 0xF0 {
                index += 1
                runningStatus = nil
                continue
            }

            if byte & 0x80 != 0 {
                runningStatus = byte
                index += 1
                continue
            }

            guard let status = runningStatus else {
                index += 1
                continue
            }

            let command = status & 0xF0

            switch command {
            case 0x90:
                guard index + 1 < bytes.count else { return notes }
                let note = bytes[index]
                let velocity = bytes[index + 1]
                if velocity > 0, note <= 127 {
                    notes.append(note)
                }
                index += 2
            case 0x80:
                guard index + 1 < bytes.count else { return notes }
                index += 2
            case 0xA0, 0xB0, 0xE0:
                guard index + 1 < bytes.count else { return notes }
                index += 2
            case 0xC0, 0xD0:
                index += 1
            default:
                index += 1
            }
        }

        return notes
    }

    private static func payloadBytes(from packet: MIDIPacket) -> [UInt8] {
        let length = min(max(0, Int(packet.length)), 256)
        guard length > 0 else { return [] }
        return withUnsafeBytes(of: packet.data) { raw in
            Array(raw.prefix(length))
        }
    }

    private static func noteNumberFromUMPWord(_ word: UInt32) -> UInt8? {
        guard (word >> 28) & 0x0F == umpMIDI1ChannelVoiceType else { return nil }
        let status = UInt8((word >> 16) & 0xFF)
        let note = UInt8((word >> 8) & 0xFF)
        let velocity = UInt8(word & 0xFF)
        guard status & 0xF0 == 0x90, velocity > 0, note <= 127 else { return nil }
        return note
    }
}
