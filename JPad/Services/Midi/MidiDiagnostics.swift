import os

enum MidiDiagnostics {
    private static let log = Logger(subsystem: "com.flickerproduct.jpad", category: "MIDI")

    static func captureStarted(sourceName: String) {
        log.info("Note capture started: \(sourceName, privacy: .public)")
    }

    static func captureStopped() {
        log.info("Note capture stopped")
    }

    static func notesReceived(_ notes: [UInt8]) {
        log.debug("Notes received: \(notes.map(String.init).joined(separator: ","), privacy: .public)")
    }
}
