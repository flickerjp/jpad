import CoreMIDI
import Foundation
import QuartzCore

/// MIDI Clock (0xF8, 24 ppqn) を受信して BPM を推定する。
/// MidiOutputService とは独立した専用クライアント・入力ポートを持ち、
/// 有効化中は全ソースへ接続する（クロック送信元の指定は不要にする）。
@MainActor
final class MidiClockReceiver: ObservableObject {
    static let tempoSourceStorageKey = "padClockTempoSourceExternal"

    /// 直近の推定 BPM。クロックが 2 秒途切れたら nil に戻る。
    @Published private(set) var estimatedBpm: Double?

    private var client = MIDIClientRef()
    private var inputPort = MIDIPortRef()
    private var connectedSources: Set<MIDIEndpointRef> = []
    private var isEnabled = false
    private var staleCheckTask: Task<Void, Never>?
    private let bridge = MidiClockTickBridge()

    func setEnabled(_ enabled: Bool) {
        guard enabled != isEnabled else { return }
        isEnabled = enabled
        if enabled {
            start()
        } else {
            stop()
        }
    }

    private func start() {
        createClientAndPortIfNeeded()
        bridge.setHandler { [weak self] bpm in
            Task { @MainActor [weak self] in
                self?.estimatedBpm = bpm
            }
        }
        connectAllSources()
        startStaleCheck()
    }

    private func stop() {
        staleCheckTask?.cancel()
        staleCheckTask = nil
        bridge.setHandler(nil)
        disconnectAllSources()
        estimatedBpm = nil
    }

    private func createClientAndPortIfNeeded() {
        if client == 0 {
            let bridgeRef = bridge
            MIDIClientCreateWithBlock("TinyRiff Clock Client" as CFString, &client) { [weak self] notification in
                guard notification.pointee.messageID == .msgSetupChanged else { return }
                Task { @MainActor [weak self] in
                    self?.reconnectSourcesIfEnabled()
                }
            }
            _ = bridgeRef
        }
        if inputPort == 0, client != 0 {
            midiClockInputPortFactory.createInputPort(client: client, bridge: bridge, port: &inputPort)
        }
    }

    private func reconnectSourcesIfEnabled() {
        guard isEnabled else { return }
        connectAllSources()
    }

    private func connectAllSources() {
        guard inputPort != 0 else { return }
        let count = MIDIGetNumberOfSources()
        var current: Set<MIDIEndpointRef> = []
        for index in 0 ..< count {
            let source = MIDIGetSource(index)
            guard source != 0 else { continue }
            guard shouldConnect(source) else { continue }
            current.insert(source)
            guard !connectedSources.contains(source) else { continue }
            MIDIPortConnectSource(inputPort, source, nil)
        }
        for stale in connectedSources.subtracting(current) {
            MIDIPortDisconnectSource(inputPort, stale)
        }
        connectedSources = current
    }

    private func disconnectAllSources() {
        guard inputPort != 0 else {
            connectedSources.removeAll()
            return
        }
        for source in connectedSources {
            MIDIPortDisconnectSource(inputPort, source)
        }
        connectedSources.removeAll()
    }

    /// SEQ/ARP の外部クロック入力では、自分が GarageBand 向けに公開している
    /// TinyRiff 仮想 MIDI source へ接続しない。自分の出力 source を入力側にも
    /// 購読すると、iOS の MIDI graph 更新時に source 認識が不安定になることがある。
    private func shouldConnect(_ source: MIDIEndpointRef) -> Bool {
        if intProperty(kMIDIPropertyUniqueID, endpoint: source) == MidiOutputService.virtualSourceUniqueID {
            return false
        }
        if endpointName(source).localizedCaseInsensitiveCompare("TinyRiff") == .orderedSame {
            return false
        }
        return true
    }

    private func endpointName(_ endpoint: MIDIEndpointRef) -> String {
        stringProperty(kMIDIPropertyDisplayName, endpoint: endpoint)
            ?? stringProperty(kMIDIPropertyName, endpoint: endpoint)
            ?? ""
    }

    private func stringProperty(_ property: CFString, endpoint: MIDIEndpointRef) -> String? {
        var unmanagedName: Unmanaged<CFString>?
        let status = MIDIObjectGetStringProperty(endpoint, property, &unmanagedName)
        guard status == noErr else { return nil }
        return unmanagedName?.takeRetainedValue() as String?
    }

    private func intProperty(_ property: CFString, endpoint: MIDIEndpointRef) -> MIDIUniqueID? {
        var value: Int32 = 0
        let status = MIDIObjectGetIntegerProperty(endpoint, property, &value)
        guard status == noErr else { return nil }
        return value
    }

    private func startStaleCheck() {
        staleCheckTask?.cancel()
        staleCheckTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self else { return }
                if self.estimatedBpm != nil, self.bridge.secondsSinceLastTick() > 2 {
                    self.estimatedBpm = nil
                }
            }
        }
    }

    deinit {
        if inputPort != 0 {
            MIDIPortDispose(inputPort)
        }
        if client != 0 {
            MIDIClientDispose(client)
        }
    }
}

/// CoreMIDI コールバックスレッドからクロックティックを集計し、
/// 1 拍 (24 tick) ごとに平滑化した BPM を main へ通知する。
private final class MidiClockTickBridge: @unchecked Sendable {
    private let lock = NSLock()
    private var handler: (@Sendable (Double) -> Void)?
    private var tickTimes: [TimeInterval] = []
    private var lastTickTime: TimeInterval = 0
    private var ticksSinceNotify = 0

    /// BPM 推定に使う直近 tick 数（2 拍ぶん）。
    private static let windowSize = 48
    /// 通知間隔（1 拍 = 24 tick ごと）。
    private static let notifyInterval = 24

    func setHandler(_ handler: (@Sendable (Double) -> Void)?) {
        lock.lock()
        self.handler = handler
        tickTimes.removeAll(keepingCapacity: true)
        ticksSinceNotify = 0
        lock.unlock()
    }

    func secondsSinceLastTick() -> TimeInterval {
        lock.lock()
        defer { lock.unlock() }
        guard lastTickTime > 0 else { return .infinity }
        return CACurrentMediaTime() - lastTickTime
    }

    func ingest(packetList: UnsafePointer<MIDIPacketList>) {
        let now = CACurrentMediaTime()
        let tickCount = MidiClockTickBridge.clockTickCount(in: packetList)
        guard tickCount > 0 else { return }

        lock.lock()
        guard let handler else {
            lock.unlock()
            return
        }
        // 同一パケット内の連続 tick はタイムスタンプを按分できないため 1 tick として扱う。
        if lastTickTime > 0, now - lastTickTime > 2 {
            tickTimes.removeAll(keepingCapacity: true)
        }
        lastTickTime = now
        tickTimes.append(now)
        if tickTimes.count > Self.windowSize {
            tickTimes.removeFirst(tickTimes.count - Self.windowSize)
        }
        ticksSinceNotify += 1

        var bpmToNotify: Double?
        if ticksSinceNotify >= Self.notifyInterval, tickTimes.count >= 25 {
            let elapsed = tickTimes.last! - tickTimes.first!
            let intervals = Double(tickTimes.count - 1)
            if elapsed > 0 {
                let bpm = 60.0 / (elapsed / intervals * 24.0)
                if (20 ... 400).contains(bpm) {
                    bpmToNotify = bpm
                }
            }
            ticksSinceNotify = 0
        }
        lock.unlock()

        if let bpm = bpmToNotify {
            handler(bpm)
        }
    }

    private static func clockTickCount(in packetList: UnsafePointer<MIDIPacketList>) -> Int {
        var count = 0
        let packetCount = min(max(0, Int(packetList.pointee.numPackets)), 64)
        guard packetCount > 0 else { return 0 }

        withUnsafePointer(to: packetList.pointee.packet) { firstPacket in
            var current = firstPacket
            for packetIndex in 0 ..< packetCount {
                let packet = current.pointee
                let length = min(max(0, Int(packet.length)), 256)
                if length > 0 {
                    withUnsafeBytes(of: packet.data) { raw in
                        for byte in raw.prefix(length) where byte == 0xF8 {
                            count += 1
                        }
                    }
                }
                if packetIndex + 1 < packetCount {
                    current = UnsafePointer(MIDIPacketNext(current))
                }
            }
        }
        return count
    }
}

/// CoreMIDI の入力コールバック登録は @MainActor 外で行う（MidiOutputService と同じ方針）。
private final class MidiClockInputPortFactory: @unchecked Sendable {
    nonisolated func createInputPort(
        client: MIDIClientRef,
        bridge: MidiClockTickBridge,
        port: inout MIDIPortRef
    ) {
        MIDIInputPortCreateWithBlock(client, "TinyRiff Clock Input" as CFString, &port) { packetList, _ in
            bridge.ingest(packetList: packetList)
        }
    }
}

private let midiClockInputPortFactory = MidiClockInputPortFactory()
