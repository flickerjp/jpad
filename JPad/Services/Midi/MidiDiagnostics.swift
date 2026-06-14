import os

enum MidiDiagnostics {
    private static let log = Logger(subsystem: "com.flickerproduct.jchord", category: "MIDI")

    static func captureStarted(sourceName: String) {
        log.info("Note capture started: \(sourceName, privacy: .public)")
    }

    static func captureStopped() {
        log.info("Note capture stopped")
    }

    static func notesReceived(_ notes: [UInt8]) {
        log.debug("Notes received: \(notes.map(String.init).joined(separator: ","), privacy: .public)")
    }

    static func endpointsRefreshed(kind: String, endpoints: [String]) {
        let joined = endpoints.isEmpty ? "-" : endpoints.joined(separator: " | ")
        log.info("MIDI \(kind, privacy: .public) endpoints: \(joined, privacy: .public)")
    }

    static func padOutputSelected(name: String, uniqueID: Int32, endpoint: UInt32, route: String) {
        log.info("PAD OUT selected route=\(route, privacy: .public) name=\(name, privacy: .public) id=\(uniqueID, privacy: .public) endpoint=\(endpoint, privacy: .public)")
    }

    static func padOutputReady(
        name: String,
        endpoint: UInt32,
        outputPort: UInt32,
        protocolLabel: String,
        isOnline: Bool
    ) {
        log.info("PAD OUT ready name=\(name, privacy: .public) endpoint=\(endpoint, privacy: .public) port=\(outputPort, privacy: .public) protocol=\(protocolLabel, privacy: .public) online=\(isOnline, privacy: .public)")
    }

    static func midiSend(
        route: String,
        destination: String,
        message: String,
        preferred: String,
        used: String,
        status: String,
        packetStatus: String,
        eventStatus: String
    ) {
        log.info("MIDI send route=\(route, privacy: .public) dest=\(destination, privacy: .public) preferred=\(preferred, privacy: .public) used=\(used, privacy: .public) status=\(status, privacy: .public) packet=\(packetStatus, privacy: .public) event=\(eventStatus, privacy: .public) msg=\(message, privacy: .public)")
    }

    static func midiSendUnavailable(route: String, reason: String) {
        log.error("MIDI send unavailable route=\(route, privacy: .public) reason=\(reason, privacy: .public)")
    }
}
