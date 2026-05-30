import Foundation

extension PadDefinition: Encodable {
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(index, forKey: .index)
        try container.encode(name, forKey: .name)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(label, forKey: .label)
        try container.encode(labelAllowsTranspose, forKey: .labelAllowsTranspose)
        try container.encode(role, forKey: .role)
        try container.encode(chordNotes, forKey: .chordNotes)
        try container.encode(bassNotes, forKey: .bassNotes)
        try container.encodeIfPresent(playbackMode, forKey: .playbackMode)
        try container.encodeIfPresent(arpeggioPattern, forKey: .arpeggioPattern)
    }
}

extension Preset: Encodable {
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(appName, forKey: .appName)
        try container.encode(setName, forKey: .setName)
        try container.encode(description, forKey: .description)
        try container.encode(version, forKey: .version)
        try container.encode(defaultPlaybackMode, forKey: .defaultPlaybackMode)
        try container.encode(autoBassOctave, forKey: .autoBassOctave)
        try container.encode(defaultChannel, forKey: .defaultChannel)
        try container.encode(defaultVelocity, forKey: .defaultVelocity)
        try container.encode(defaultExpression, forKey: .defaultExpression)
        try container.encode(transposeSettings, forKey: .transposeSettings)
        try container.encode(pads, forKey: .pads)
    }
}
