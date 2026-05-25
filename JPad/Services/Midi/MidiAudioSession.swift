import AVFoundation
import Foundation

/// iOS の AVAudioSession（TinyTone 内蔵再生と GarageBand / 仮想 MIDI 共存で使い分け）。
enum MidiAudioSession {
    static var hasBackgroundAudioMode: Bool {
        guard let modes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String] else {
            return false
        }
        return modes.contains("audio")
    }

    /// GarageBand や外部 MIDI と共存（他アプリの音とミックス）。
    @discardableResult
    static func activateForSharedMIDI() -> OSStatus {
        activatePlaybackSession(options: [.mixWithOthers], preferredSampleRate: 48_000)
    }

    @discardableResult
    static func activateForVirtualMIDI() -> OSStatus {
        activateForSharedMIDI()
    }

    /// TinyTone など内蔵プレビュー専用（他アプリ音とミックスしない）。
    @discardableResult
    static func activateForInternalPreview() -> OSStatus {
        let status = activatePlaybackSession(options: [], preferredSampleRate: nil)
        guard status == noErr else { return status }

        let session = AVAudioSession.sharedInstance()
        do {
            try session.overrideOutputAudioPort(.speaker)
            return noErr
        } catch {
            return noErr
        }
    }

    /// セッション確定後のサンプルレートでバッファと PlayerNode を接続する。
    static func playbackFormatForInternalPreview() -> AVAudioFormat? {
        let session = AVAudioSession.sharedInstance()
        let rate = session.sampleRate > 8_000 ? session.sampleRate : 48_000
        return AVAudioFormat(standardFormatWithSampleRate: rate, channels: 2)
    }

    @discardableResult
    private static func activatePlaybackSession(
        options: AVAudioSession.CategoryOptions,
        preferredSampleRate: Double?
    ) -> OSStatus {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: options)
            if let preferredSampleRate {
                try session.setPreferredSampleRate(preferredSampleRate)
            }
            try session.setActive(true)
            return noErr
        } catch {
            return OSStatus((error as NSError).code)
        }
    }
}
