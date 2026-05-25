import SwiftUI

struct PadEditorRootKeyboardStyle {
    let panelBackground: Color
    let keyIdleBackground: Color
    let keySelectedBackground: Color
    /// 選択＝渋オレンジ、発音中＝明るいオレンジ（TEST NOTE 同系）
    let usesMidiAccentHighlight: Bool
    let fillsAvailableWidth: Bool

    static let standard = PadEditorRootKeyboardStyle(
        panelBackground: .clear,
        keyIdleBackground: Color.white.opacity(0.05),
        keySelectedBackground: Color.white.opacity(0.12),
        usesMidiAccentHighlight: false,
        fillsAvailableWidth: false
    )

    static let v11 = PadEditorRootKeyboardStyle(
        panelBackground: .black,
        keyIdleBackground: Color.white.opacity(0.10),
        keySelectedBackground: .clear,
        usesMidiAccentHighlight: true,
        fillsAvailableWidth: true
    )
}

/// v1 / v1.1 共有の 12 鍵ルート鍵盤（`PadEditorView.rootKeyboard` と同レイアウト）。
///
/// v1.1 NOTE INPUT: `registeredRootsInZone` = 現在 OCT の bass+chord。
/// `selectedRoot` = 操作対象の一時選択（ROOT 右の確定 bass とは別）。
struct PadEditorRootKeyboardView: View {
    let metrics: PadEditorMetrics
    /// 12 鍵の一時選択（ADD / DEL / ROOT 用）。確定 bass は `v11BassNotesLabel`。
    let selectedRoot: String?
    /// 現在 OCT 内の登録済みピッチクラス（`bassNotes` + `chordNotes`）
    var registeredRootsInZone: Set<String> = []
    /// 押下試聴中の鍵（明るいオレンジ）
    var soundingRoot: String? = nil
    let onSelectRoot: (String) -> Void
    var onRootSoundingChanged: ((String, Bool) -> Void)? = nil
    var style: PadEditorRootKeyboardStyle = .standard
    var keyWidth: CGFloat?
    var keySpacing: CGFloat?
    var panelHorizontalPadding: CGFloat = 10
    var panelVerticalPadding: CGFloat = 10

    private static let naturalRoots = ["C", "D", "E", "F", "G", "A", "B"]
    private static let rootSharpPlacements: [RootSharpPlacement] = [
        RootSharpPlacement(name: "C#", afterNaturalIndex: 0),
        RootSharpPlacement(name: "Eb", afterNaturalIndex: 1),
        RootSharpPlacement(name: "F#", afterNaturalIndex: 3),
        RootSharpPlacement(name: "Ab", afterNaturalIndex: 4),
        RootSharpPlacement(name: "Bb", afterNaturalIndex: 5),
    ]

    var body: some View {
        Group {
            if style.fillsAvailableWidth {
                keyboardKeys
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, panelHorizontalPadding)
                    .padding(.vertical, panelVerticalPadding)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(style.panelBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                keyboardKeys
                    .padding(.horizontal, panelHorizontalPadding)
                    .padding(.vertical, panelVerticalPadding)
                    .frame(maxWidth: .infinity)
                    .background(style.panelBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    private var keyboardKeys: some View {
        let resolvedKeyWidth = keyWidth ?? metrics.rootKeyWidth
        let spacing = keySpacing ?? metrics.rootKeySpacing
        let rowWidth = resolvedKeyWidth * 7 + spacing * 6

        return VStack(alignment: .center, spacing: metrics.rootRowSpacing) {
            ZStack(alignment: .topLeading) {
                Color.clear
                    .frame(width: rowWidth, height: metrics.controlHeight)

                ForEach(Self.rootSharpPlacements) { placement in
                    rootKey(placement.name, width: resolvedKeyWidth)
                        .offset(
                            x: rootSharpOffsetX(
                                afterNaturalIndex: placement.afterNaturalIndex,
                                keyWidth: resolvedKeyWidth,
                                spacing: spacing
                            )
                        )
                }
            }
            .frame(width: rowWidth, height: metrics.controlHeight)

            HStack(spacing: spacing) {
                ForEach(Self.naturalRoots, id: \.self) { root in
                    rootKey(root, width: resolvedKeyWidth)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func rootSharpOffsetX(
        afterNaturalIndex index: Int,
        keyWidth: CGFloat,
        spacing: CGFloat
    ) -> CGFloat {
        let leftEdge = CGFloat(index) * (keyWidth + spacing)
        let rightEdge = CGFloat(index + 1) * (keyWidth + spacing)
        let center = (leftEdge + keyWidth + rightEdge) / 2
        return center - keyWidth / 2
    }

    private func rootKey(_ root: String, width: CGFloat) -> some View {
        let normalizedKey = RootPitch.normalize(root)
        let isSelected = selectedRoot.map(RootPitch.normalize) == normalizedKey
        let isRegistered = registeredRootsInZone.contains(normalizedKey)
        let isSounding = soundingRoot == root
        let keyShape = RoundedRectangle(cornerRadius: 14, style: .continuous)

        return Text(root)
            .font(.subheadline.weight(.heavy))
            .foregroundStyle(keyForeground(isSelected: isSelected, isRegistered: isRegistered, isSounding: isSounding))
            .frame(width: width)
            .frame(height: metrics.controlHeight)
            .background(keyBackground(isSelected: isSelected, isRegistered: isRegistered, isSounding: isSounding), in: keyShape)
            .overlay(
                keyShape.strokeBorder(
                    keyBorder(isSelected: isSelected, isRegistered: isRegistered, isSounding: isSounding),
                    lineWidth: isSounding ? 2 : 1
                )
            )
            .contentShape(keyShape)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        onSelectRoot(root)
                        onRootSoundingChanged?(root, true)
                    }
                    .onEnded { _ in
                        onRootSoundingChanged?(root, false)
                    }
            )
    }

    private func keyForeground(isSelected: Bool, isRegistered: Bool, isSounding: Bool) -> Color {
        if isSounding {
            return .white.opacity(0.96)
        }
        if style.usesMidiAccentHighlight, isRegistered {
            return JChordTheme.midiDeviceSelectedForeground
        }
        return JChordTheme.text
    }

    private func keyBackground(isSelected: Bool, isRegistered: Bool, isSounding: Bool) -> AnyShapeStyle {
        if isSounding {
            return AnyShapeStyle(JChordTheme.padActiveBackground)
        }
        if style.usesMidiAccentHighlight, isRegistered {
            return AnyShapeStyle(JChordTheme.midiDeviceSelectedBackground)
        }
        if isSelected {
            return AnyShapeStyle(style.keySelectedBackground)
        }
        return AnyShapeStyle(style.keyIdleBackground)
    }

    private func keyBorder(isSelected: Bool, isRegistered: Bool, isSounding: Bool) -> Color {
        if isSounding {
            return Color.white.opacity(0.28)
        }
        if style.usesMidiAccentHighlight {
            if isSelected {
                return JChordTheme.midiDeviceSelectedBorder
            }
            if isRegistered {
                return JChordTheme.midiDeviceSelectedBorder
            }
            return JChordTheme.padBorder
        }
        return Color.clear
    }
}

struct RootSharpPlacement: Identifiable {
    let name: String
    let afterNaturalIndex: Int

    var id: String { name }
}
