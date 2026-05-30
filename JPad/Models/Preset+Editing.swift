import Foundation

extension Preset {
    func withSetName(_ newName: String) -> Preset {
        Preset(
            id: id,
            appName: appName,
            setName: newName,
            description: description,
            version: version,
            defaultPlaybackMode: defaultPlaybackMode,
            autoBassOctave: autoBassOctave,
            defaultChannel: defaultChannel,
            defaultVelocity: defaultVelocity,
            defaultExpression: defaultExpression,
            transposeSettings: transposeSettings,
            pads: pads
        )
    }

    func replacingPad(_ pad: PadDefinition) -> Preset {
        Preset(
            id: id,
            appName: appName,
            setName: setName,
            description: description,
            version: version,
            defaultPlaybackMode: defaultPlaybackMode,
            autoBassOctave: autoBassOctave,
            defaultChannel: defaultChannel,
            defaultVelocity: defaultVelocity,
            defaultExpression: defaultExpression,
            transposeSettings: transposeSettings,
            pads: pads.map { $0.index == pad.index ? pad : $0 }
        )
    }

    func replacingControlSettings(_ newSettings: PresetControlSettings) -> Preset {
        Preset(
            id: id,
            appName: appName,
            setName: setName,
            description: description,
            version: version,
            defaultPlaybackMode: defaultPlaybackMode,
            autoBassOctave: autoBassOctave,
            defaultChannel: defaultChannel,
            defaultVelocity: defaultVelocity,
            defaultExpression: defaultExpression,
            transposeSettings: newSettings,
            pads: pads
        )
    }

    func replacingPerformanceSettings(
        defaultVelocity newVelocity: UInt8,
        defaultExpression newExpression: UInt8
    ) -> Preset {
        Preset(
            id: id,
            appName: appName,
            setName: setName,
            description: description,
            version: version,
            defaultPlaybackMode: defaultPlaybackMode,
            autoBassOctave: autoBassOctave,
            defaultChannel: defaultChannel,
            defaultVelocity: newVelocity,
            defaultExpression: newExpression,
            transposeSettings: transposeSettings,
            pads: pads
        )
    }
}
