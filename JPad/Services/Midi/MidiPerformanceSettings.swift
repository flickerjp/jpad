import Foundation

/// メイン画面の Velocity / Expression（セット横断で共通）。
enum MidiPerformanceSettings {
    static let velocityKey = "jpad.midi.velocity"
    static let expressionKey = "jpad.midi.expression"
    static let defaultValue: Double = 100
}
