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
            pads: pads.map { $0.index == pad.index ? pad : $0 }
        )
    }
}
