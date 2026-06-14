import AVFoundation
import Foundation
import TinyToneCore

/// JPad 内蔵プレビュー — `TinyToneCore` エンジン + セッション復帰。
final class TinyToneEngine: InternalPreviewSynth, @unchecked Sendable {
    private let core: TinyToneAudioEngine
    private var sessionObservers: [NSObjectProtocol] = []
    private var shouldResumeAfterInterruption = false

    var isEngineRunning: Bool { core.isRunning }
    var activeVoiceCount: Int { core.activeVoiceCount }
    var lastStartError: String? { core.lastStartError }

    init() {
        core = TinyToneAudioEngine(
            configuration: TinyToneAudioConfiguration(
                initialPatch: .jpadFactory,
                outputGateRampSeconds: 0.04,
                preparePlayback: {
                    guard MidiAudioSession.activateForInternalPreview() == noErr else { return nil }
                    return MidiAudioSession.playbackFormatForInternalPreview()
                }
            )
        )
        registerSessionObservers()
    }

    deinit {
        for token in sessionObservers {
            NotificationCenter.default.removeObserver(token)
        }
    }

    @discardableResult
    func start() -> Bool {
        core.start()
    }

    func stop() {
        core.stop()
        shouldResumeAfterInterruption = false
    }

    func noteOn(noteNumber: Int, velocity: UInt8) {
        core.noteOn(noteNumber: noteNumber, velocity: velocity)
    }

    func noteOff(noteNumber: Int) {
        core.noteOff(noteNumber: noteNumber)
    }

    func chordOn(noteNumbers: [Int], velocity: UInt8) {
        core.chordOn(noteNumbers: noteNumbers, velocity: velocity)
    }

    func chordOff(noteNumbers: [Int]) {
        core.chordOff(noteNumbers: noteNumbers)
    }

    func allNotesOff() {
        core.allNotesOff()
    }

    func setPreviewLevel(_ level: Float) {
        core.setPreviewLevel(level)
    }

    func loadSoundPatch(from data: Data) throws {
        try core.loadSoundPatch(from: data)
    }

    func prepareSoundPatch(from data: Data) throws {
        try core.prepareSoundPatch(from: data)
    }

    func updatePatch(_ patch: TinyTonePatch) {
        core.updatePatch(patch)
    }

    func resetRenderMetrics() {
        core.resetRenderMetrics()
    }

    private func registerSessionObservers() {
        let session = AVAudioSession.sharedInstance()
        let center = NotificationCenter.default

        sessionObservers.append(
            center.addObserver(
                forName: AVAudioSession.interruptionNotification,
                object: session,
                queue: .main
            ) { [weak self] notification in
                self?.handleInterruption(notification)
            }
        )

        sessionObservers.append(
            center.addObserver(
                forName: AVAudioSession.routeChangeNotification,
                object: session,
                queue: .main
            ) { [weak self] notification in
                self?.handleRouteChange(notification)
            }
        )
    }

    private func handleInterruption(_ notification: Notification) {
        guard let value = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: value) else {
            return
        }

        switch type {
        case .began:
            shouldResumeAfterInterruption = isEngineRunning
            allNotesOff()
            stop()
        case .ended:
            guard shouldResumeAfterInterruption else { return }
            allNotesOff()
            _ = start()
        @unknown default:
            break
        }
    }

    private func handleRouteChange(_ notification: Notification) {
        guard let reasonValue = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }

        switch reason {
        case .newDeviceAvailable, .oldDeviceUnavailable, .categoryChange, .override, .wakeFromSleep:
            guard isEngineRunning else { return }
            allNotesOff()
            stop()
            _ = start()
        default:
            break
        }
    }
}
