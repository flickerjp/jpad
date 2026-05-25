import Foundation

enum MidiMessageBuilder {
    enum SystemRealTime: UInt8 {
        case start = 0xFA
        case `continue` = 0xFB
        case stop = 0xFC
    }

    static func noteOn(note: UInt8, velocity: UInt8, channel: UInt8) -> [UInt8] {
        [0x90 | (channel & 0x0F), note, velocity]
    }

    static func noteOff(note: UInt8, channel: UInt8) -> [UInt8] {
        [0x80 | (channel & 0x0F), note, 0]
    }

    static func controlChange(controller: UInt8, value: UInt8, channel: UInt8) -> [UInt8] {
        [0xB0 | (channel & 0x0F), controller, value]
    }

    static func systemRealTime(_ event: SystemRealTime) -> [UInt8] {
        [event.rawValue]
    }

    /// CC 11 — Expression (real-time level)
    static func expression(_ value: UInt8, channel: UInt8) -> [UInt8] {
        controlChange(controller: 11, value: value, channel: channel)
    }

    /// CC 64 — Sustain pedal
    static func sustainPedal(_ isDown: Bool, channel: UInt8) -> [UInt8] {
        controlChange(controller: 64, value: isDown ? 127 : 0, channel: channel)
    }

    /// CC 120 — All Sound Off (immediate silence on many hosts)
    static func allSoundOff(channel: UInt8) -> [UInt8] {
        controlChange(controller: 120, value: 0, channel: channel)
    }

    /// CC 121 — Reset All Controllers
    static func resetAllControllers(channel: UInt8) -> [UInt8] {
        controlChange(controller: 121, value: 0, channel: channel)
    }

    /// CC 123 — All Notes Off (MIDI 1.0)
    static func allNotesOff(channel: UInt8) -> [UInt8] {
        controlChange(controller: 123, value: 0, channel: channel)
    }
}

/// 設定画面の TEST NOTE 下から送れる Note On/Off 以外の MIDI（サンプラー停止の試験用）。
enum MidiUtilityCommand: String, CaseIterable, Identifiable {
    case midiStop
    case midiStart
    case midiContinue
    case sustainOff
    case allSoundOff
    case allNotesOff
    case resetControllers
    case panicCurrentChannel
    case panicAllChannels

    var id: String { rawValue }

    /// 設定の MIDI COMMANDS メニューに出すコマンド（`panicCurrentChannel` は非表示）。
    static var settingsMenuCommands: [MidiUtilityCommand] {
        allCases.filter { $0 != .panicCurrentChannel }
    }

    var titleKey: String {
        "settings.midi_command.\(rawValue)"
    }

    var title: String {
        L10n.string(titleKey)
    }

    func messages(channel: UInt8) -> [[UInt8]] {
        switch self {
        case .midiStop:
            return [MidiMessageBuilder.systemRealTime(.stop)]
        case .midiStart:
            return [MidiMessageBuilder.systemRealTime(.start)]
        case .midiContinue:
            return [MidiMessageBuilder.systemRealTime(.continue)]
        case .sustainOff:
            return [MidiMessageBuilder.sustainPedal(false, channel: channel)]
        case .allSoundOff:
            return [MidiMessageBuilder.allSoundOff(channel: channel)]
        case .allNotesOff:
            return [MidiMessageBuilder.allNotesOff(channel: channel)]
        case .resetControllers:
            return [MidiMessageBuilder.resetAllControllers(channel: channel)]
        case .panicCurrentChannel:
            return [
                MidiMessageBuilder.sustainPedal(false, channel: channel),
                MidiMessageBuilder.allSoundOff(channel: channel),
                MidiMessageBuilder.allNotesOff(channel: channel),
            ]
        case .panicAllChannels:
            var messages: [[UInt8]] = []
            for ch in UInt8(0)..<16 {
                messages.append(MidiMessageBuilder.sustainPedal(false, channel: ch))
                messages.append(MidiMessageBuilder.allSoundOff(channel: ch))
                messages.append(MidiMessageBuilder.allNotesOff(channel: ch))
            }
            messages.append(MidiMessageBuilder.systemRealTime(.stop))
            return messages
        }
    }
}
