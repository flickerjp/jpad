import Foundation

extension Preset {
    func withSetName(_ newName: String) -> Preset {
        copying(setName: newName)
    }

    func replacingPad(_ pad: PadDefinition) -> Preset {
        copying(pads: pads.map { $0.index == pad.index ? pad : $0 })
    }

    func replacingControlSettings(_ newSettings: PresetControlSettings) -> Preset {
        copying(transposeSettings: newSettings)
    }

    func replacingSequencerSettings(_ newSettings: PresetSequencerSettings) -> Preset {
        copying(sequencerSettings: newSettings)
    }

    func replacingPerformanceSettings(
        defaultVelocity newVelocity: UInt8,
        defaultExpression newExpression: UInt8
    ) -> Preset {
        copying(defaultVelocity: newVelocity, defaultExpression: newExpression)
    }

    private func copying(
        setName: String? = nil,
        defaultVelocity: UInt8? = nil,
        defaultExpression: UInt8? = nil,
        transposeSettings: PresetControlSettings? = nil,
        sequencerSettings: PresetSequencerSettings? = nil,
        pads: [PadDefinition]? = nil
    ) -> Preset {
        Preset(
            id: id,
            appName: appName,
            setName: setName ?? self.setName,
            description: description,
            version: version,
            defaultPlaybackMode: defaultPlaybackMode,
            autoBassOctave: autoBassOctave,
            defaultChannel: defaultChannel,
            defaultVelocity: defaultVelocity ?? self.defaultVelocity,
            defaultExpression: defaultExpression ?? self.defaultExpression,
            transposeSettings: transposeSettings ?? self.transposeSettings,
            sequencerSettings: sequencerSettings ?? self.sequencerSettings,
            pads: pads ?? self.pads
        )
    }
}
