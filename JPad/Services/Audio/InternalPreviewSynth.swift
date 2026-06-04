import Foundation

enum PreviewSoundImportError: LocalizedError {
    case unsupportedEngine
    case invalidUTF8
    case invalidPatch

    var errorDescription: String? {
        switch self {
        case .unsupportedEngine:
            return "This preview engine does not accept TinyTone JSON."
        case .invalidUTF8:
            return "The JSON text could not be decoded."
        case .invalidPatch:
            return "The JSON did not contain a valid TinyTone patch."
        }
    }
}

/// 内蔵 PAD OUT プレビュー（TinyTone JSON 対応）。
protocol InternalPreviewSynth: AnyObject, Sendable {
    var isEngineRunning: Bool { get }
    var activeVoiceCount: Int { get }
    var lastStartError: String? { get }

    @discardableResult
    func start() -> Bool
    func stop()
    func noteOn(noteNumber: Int, velocity: UInt8)
    func noteOff(noteNumber: Int)
    func chordOn(noteNumbers: [Int], velocity: UInt8)
    func chordOff(noteNumbers: [Int])
    func allNotesOff()
    func setPreviewLevel(_ level: Float)
    func loadSoundPatch(from data: Data) throws
    func prepareSoundPatch(from data: Data) throws
    func updatePatch(_ patch: TinyTonePatch)
    func resetRenderMetrics()
}
