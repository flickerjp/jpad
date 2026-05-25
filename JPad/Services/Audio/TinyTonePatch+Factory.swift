import Foundation
import TinyToneCore

extension TinyTonePatch {
    /// Default factory program (`TinyTone.json` in TinyToneCore).
    static let jpadFactory: TinyTonePatch = {
        guard let patch = TinyToneFactoryPresets.patch(named: "TinyTone") else {
            fatalError("Factory preset TinyTone.json is missing from TinyToneCore.")
        }
        return patch
    }()

    static let defaultPatch = jpadFactory
}
