import SwiftUI

// MARK: - 共通: パターンスロットボタン (1〜4)

struct SequencerSlotButton: View {
    let index: Int
    let isSelected: Bool
    let hasContent: Bool
    var width: CGFloat?
    var height: CGFloat
    var cornerRadius: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text("\(index + 1)")
                    .font(.system(size: max(15, height * 0.34), weight: .heavy))
                    .monospacedDigit()
                Circle()
                    .fill(hasContent ? JPadChromeTheme.accentLight : Color.white.opacity(0.25))
                    .frame(width: 5, height: 5)
            }
            .foregroundStyle(
                isSelected ? JPadChromeTheme.buttonLabelFilled : Color.white.opacity(0.9)
            )
            .frame(maxWidth: .infinity, minHeight: height, alignment: .center)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        isSelected
                            ? AnyShapeStyle(JPadChromeTheme.buttonIdleFill)
                            : AnyShapeStyle(Color.clear)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        isSelected ? JPadChromeTheme.buttonIdleBorder : Color.white.opacity(0.85),
                        lineWidth: 1.2
                    )
            )
        }
        .buttonStyle(.plain)
        .frame(width: width)
        .accessibilityLabel("Pattern \(index + 1)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - ARP 縦表示コントロール

struct ArpControlRows: View {
    @ObservedObject var viewModel: MainViewModel
    let layout: JChordPadLayout

    private var slotHeight: CGFloat {
        max(36, layout.noteOffHeight * 0.52)
    }

    private var transportHeight: CGFloat {
        max(32, layout.noteOffHeight * 0.5)
    }

    private var topCellWidth: CGFloat {
        floor((layout.gridWidth - layout.gridSpacing * 4) / 5)
    }

    private var transportButtonWidth: CGFloat {
        floor((layout.gridWidth - layout.gridSpacing * 5) / 6)
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: layout.gridSpacing) {
                ForEach(0 ..< PresetArpSettings.slotCount, id: \.self) { index in
                    SequencerSlotButton(
                        index: index,
                        isSelected: viewModel.arpSettings.selectedSlotIndex == index,
                        hasContent: !viewModel.arpSettings.slots[index].isEmpty,
                        width: topCellWidth,
                        height: slotHeight,
                        cornerRadius: min(layout.padCornerRadius, slotHeight * 0.32),
                        action: { viewModel.selectArpSlot(index) }
                    )
                }

                SequencerGateWheel(
                    gate: Binding(
                        get: { Int((viewModel.arpSettings.selectedSlot.gate * 100).rounded()) },
                        set: { viewModel.updateArpGate(Double($0) / 100) }
                    ),
                    width: topCellWidth,
                    height: slotHeight
                )
            }
            .frame(width: layout.gridWidth)

            ArpStepDisplay(
                slot: viewModel.arpSettings.selectedSlot,
                width: layout.gridWidth
            )

            HStack(spacing: layout.gridSpacing) {
                JPadChromeDockButton(
                    title: L10n.string("main.arp.on"),
                    style: .accentToggle,
                    isOn: viewModel.isArpPerformanceOn,
                    fontSize: 12,
                    width: transportButtonWidth,
                    height: transportHeight,
                    action: { viewModel.toggleArpPerformance() }
                )
                .jChordGentlePulse(viewModel.isArpPerformanceOn)

                JPadChromeDockButton(
                    title: L10n.string("main.arp.edit"),
                    style: .outline,
                    fontSize: 12,
                    width: transportButtonWidth,
                    height: transportHeight,
                    action: { viewModel.presentArpEditor() }
                )

                Spacer(minLength: 0)
            }
            .frame(width: layout.gridWidth)
        }
    }
}

// MARK: - SEQ 縦表示コントロール

struct SeqControlRows: View {
    @ObservedObject var viewModel: MainViewModel
    let layout: JChordPadLayout

    private var slotHeight: CGFloat {
        max(36, layout.noteOffHeight * 0.52)
    }

    private var transportHeight: CGFloat {
        max(32, layout.noteOffHeight * 0.5)
    }

    private var topCellWidth: CGFloat {
        floor((layout.gridWidth - layout.gridSpacing * 4) / 5)
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: layout.gridSpacing) {
                ForEach(0 ..< PresetSeqSettings.slotCount, id: \.self) { index in
                    SequencerSlotButton(
                        index: index,
                        isSelected: viewModel.seqSettings.selectedSlotIndex == index,
                        hasContent: !viewModel.seqSettings.slots[index].steps.isEmpty,
                        width: topCellWidth,
                        height: slotHeight,
                        cornerRadius: min(layout.padCornerRadius, slotHeight * 0.32),
                        action: { viewModel.selectSeqSlot(index) }
                    )
                }

                SequencerGateWheel(
                    gate: Binding(
                        get: { Int((viewModel.seqSettings.gate * 100).rounded()) },
                        set: { viewModel.updateSeqGate(Double($0) / 100) }
                    ),
                    width: topCellWidth,
                    height: slotHeight
                )
            }
            .frame(width: layout.gridWidth)

            SeqStepDisplay(
                steps: viewModel.seqSettings.selectedSlot.steps,
                currentRawStep: viewModel.sequencerEngine.seqCurrentRawStep,
                isRecording: viewModel.isSeqRecording,
                width: layout.gridWidth
            )

            HStack(spacing: layout.gridSpacing) {
                seqTransportButton(
                    title: viewModel.sequencerEngine.isSeqPlaying
                        ? L10n.string("main.seq.stop")
                        : L10n.string("main.seq.play"),
                    style: .accentToggle,
                    isOn: viewModel.sequencerEngine.isSeqPlaying
                ) {
                    viewModel.toggleSeqPlayback()
                }
                .jChordGentlePulse(viewModel.sequencerEngine.isSeqPlaying)

                seqTransportButton(
                    title: L10n.string("main.seq.rec"),
                    style: .accentToggle,
                    isOn: viewModel.isSeqRecording
                ) {
                    viewModel.toggleSeqRecording()
                }

                seqTransportButton(title: L10n.string("main.seq.tie"), enabled: viewModel.isSeqRecording) {
                    viewModel.recordSeqTie()
                }

                seqTransportButton(title: L10n.string("main.seq.rest"), enabled: viewModel.isSeqRecording) {
                    viewModel.recordSeqRest()
                }

                seqTransportButton(title: L10n.string("main.seq.delete"), enabled: viewModel.isSeqRecording) {
                    viewModel.deleteLastSeqStep()
                }

                seqTransportButton(title: L10n.string("main.seq.clear")) {
                    viewModel.clearSeqPattern()
                }
            }
            .frame(width: layout.gridWidth)
        }
    }

    private func seqTransportButton(
        title: String,
        style: JPadChromeDockButton.Style = .outline,
        isOn: Bool = false,
        enabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        JPadChromeDockButton(
            title: title,
            style: style,
            isOn: isOn,
            fontSize: 12,
            width: floor((layout.gridWidth - layout.gridSpacing * 5) / 6),
            height: transportHeight,
            action: action
        )
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
    }
}

// MARK: - SEQ ステップ表示 (16 セル)

struct ArpStepDisplay: View {
    let slot: ArpPatternSlot
    let width: CGFloat

    private static let cellSpacing: CGFloat = 3

    var body: some View {
        let cellWidth = floor((width - Self.cellSpacing * CGFloat(ArpPatternSlot.stepCount - 1)) / CGFloat(ArpPatternSlot.stepCount))
        HStack(spacing: Self.cellSpacing) {
            ForEach(0 ..< ArpPatternSlot.stepCount, id: \.self) { step in
                stepCell(at: step, cellWidth: cellWidth)
            }
        }
        .frame(width: width)
    }

    private func stepCell(at step: Int, cellWidth: CGFloat) -> some View {
        let activeVoices = (0 ..< ArpPatternSlot.voiceCount).filter { voice in
            slot.steps.indices.contains(voice)
                && slot.steps[voice].indices.contains(step)
                && slot.steps[voice][step]
        }

        return VStack(spacing: 2) {
            ForEach(0 ..< ArpPatternSlot.voiceCount, id: \.self) { voice in
                Capsule()
                    .fill(
                        activeVoices.contains(voice)
                            ? JPadChromeTheme.accentLight
                            : Color.white.opacity(0.12)
                    )
                    .frame(width: max(5, cellWidth * 0.48), height: 3)
            }
        }
        .frame(width: cellWidth, height: max(22, cellWidth * 1.05))
        .background(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color.white.opacity(step % 4 == 0 ? 0.08 : 0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .strokeBorder(Color.white.opacity(activeVoices.isEmpty ? 0.2 : 0.35), lineWidth: 1)
        )
    }
}

struct SeqStepDisplay: View {
    let steps: [SeqStep]
    let currentRawStep: Int?
    let isRecording: Bool
    let width: CGFloat

    private static let cellSpacing: CGFloat = 3

    var body: some View {
        let cellWidth = floor((width - Self.cellSpacing * CGFloat(SeqPatternSlot.maxStepCount - 1)) / CGFloat(SeqPatternSlot.maxStepCount))
        HStack(spacing: Self.cellSpacing) {
            ForEach(0 ..< SeqPatternSlot.maxStepCount, id: \.self) { index in
                stepCell(at: index, cellWidth: cellWidth)
            }
        }
        .frame(width: width)
    }

    @ViewBuilder
    private func stepCell(at index: Int, cellWidth: CGFloat) -> some View {
        let isPlayingHere = currentRawStep == index
        let isNextEntry = isRecording && index == steps.count
        let label = stepLabel(at: index)

        Text(label)
            .font(.system(size: max(9, cellWidth * 0.42), weight: .heavy))
            .monospacedDigit()
            .foregroundStyle(
                isPlayingHere
                    ? JPadChromeTheme.buttonLabelFilled
                    : (index < steps.count ? JChordTheme.text : JChordTheme.muted.opacity(0.5))
            )
            .frame(width: cellWidth, height: max(22, cellWidth * 1.05))
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(
                        isPlayingHere
                            ? AnyShapeStyle(JPadChromeTheme.buttonIdleFill)
                            : AnyShapeStyle(Color.white.opacity(index % 4 == 0 ? 0.08 : 0.04))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(
                        isNextEntry
                            ? JPadChromeTheme.accentLight
                            : Color.white.opacity(0.2),
                        lineWidth: isNextEntry ? 1.4 : 1
                    )
            )
    }

    private func stepLabel(at index: Int) -> String {
        guard index < steps.count else { return "" }
        let step = steps[index]
        switch step.kind {
        case .pad:
            guard let padIndex = step.padIndex else { return "?" }
            return "\(padIndex + 1)"
        case .tie:
            return "‒"
        case .rest:
            return "·"
        }
    }
}

// MARK: - GATE ホイール

struct SequencerGateWheel: View {
    @Binding var gate: Int
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        JChordValueWheelPicker(
            values: Array(stride(from: 100, through: 5, by: -5)),
            value: $gate,
            width: width,
            height: height,
            displayText: { "\($0)" }
        )
        .frame(width: width, height: height)
        .clipped()
        .accessibilityLabel(L10n.string("main.seq.gate"))
    }
}

// MARK: - 横表示パネル (スロット選択は横でも可能)

struct ArpLandscapePanel: View {
    @ObservedObject var viewModel: MainViewModel
    let layout: JChordPadLayout

    var body: some View {
        VStack(spacing: layout.gridSpacing) {
            ForEach(0 ..< PresetArpSettings.slotCount, id: \.self) { index in
                SequencerSlotButton(
                    index: index,
                    isSelected: viewModel.arpSettings.selectedSlotIndex == index,
                    hasContent: !viewModel.arpSettings.slots[index].isEmpty,
                    width: layout.landscapeControlPanelWidth,
                    height: 44,
                    cornerRadius: 10,
                    action: { viewModel.selectArpSlot(index) }
                )
            }

            JPadChromeDockButton(
                title: L10n.string("main.arp.on"),
                style: .accentToggle,
                isOn: viewModel.isArpPerformanceOn,
                fontSize: 13,
                width: layout.landscapeControlPanelWidth,
                height: 34,
                action: { viewModel.toggleArpPerformance() }
            )
            .jChordGentlePulse(viewModel.isArpPerformanceOn)

            SequencerGateWheel(
                gate: Binding(
                    get: { Int((viewModel.arpSettings.selectedSlot.gate * 100).rounded()) },
                    set: { viewModel.updateArpGate(Double($0) / 100) }
                ),
                width: layout.landscapeControlPanelWidth,
                height: 34
            )
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

struct SeqLandscapePanel: View {
    @ObservedObject var viewModel: MainViewModel
    let layout: JChordPadLayout

    var body: some View {
        VStack(spacing: layout.gridSpacing) {
            ForEach(0 ..< PresetSeqSettings.slotCount, id: \.self) { index in
                SequencerSlotButton(
                    index: index,
                    isSelected: viewModel.seqSettings.selectedSlotIndex == index,
                    hasContent: !viewModel.seqSettings.slots[index].steps.isEmpty,
                    width: layout.landscapeControlPanelWidth,
                    height: 44,
                    cornerRadius: 10,
                    action: { viewModel.selectSeqSlot(index) }
                )
            }

            JPadChromeDockButton(
                title: viewModel.sequencerEngine.isSeqPlaying
                    ? L10n.string("main.seq.stop")
                    : L10n.string("main.seq.play"),
                style: .accentToggle,
                isOn: viewModel.sequencerEngine.isSeqPlaying,
                fontSize: 13,
                width: layout.landscapeControlPanelWidth,
                height: 34,
                action: { viewModel.toggleSeqPlayback() }
            )
            .jChordGentlePulse(viewModel.sequencerEngine.isSeqPlaying)

            SequencerGateWheel(
                gate: Binding(
                    get: { Int((viewModel.seqSettings.gate * 100).rounded()) },
                    set: { viewModel.updateSeqGate(Double($0) / 100) }
                ),
                width: layout.landscapeControlPanelWidth,
                height: 34
            )
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

// MARK: - ARP パターンエディタ (パッドエリアも使う全面オーバーレイ)

struct ArpPatternEditorOverlay: View {
    @ObservedObject var viewModel: MainViewModel

    private static let stepSpacing: CGFloat = 3
    private static let voiceLabels = ["U", "M", "L"]

    var body: some View {
        GeometryReader { geometry in
            let contentWidth = min(geometry.size.width - 32, 520)

            ZStack {
                JPadChromeTheme.mainScreenBackground
                    .ignoresSafeArea()

                VStack(spacing: 14) {
                    header(contentWidth: contentWidth)
                    slotRow(contentWidth: contentWidth)
                    stepGrid(contentWidth: contentWidth)
                    keyRow(contentWidth: contentWidth)
                    Spacer(minLength: 0)
                }
                .frame(width: contentWidth)
                .padding(.top, max(16, geometry.safeAreaInsets.top))
            }
        }
    }

    private func header(contentWidth: CGFloat) -> some View {
        HStack {
            Text(L10n.string("main.arp.editor_title"))
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(JChordTheme.text)

            Spacer(minLength: 0)

            JPadChromeDockButton(
                title: L10n.string("main.done"),
                style: .accentToggle,
                isOn: true,
                width: 88,
                height: 34,
                action: { viewModel.dismissArpEditor() }
            )
        }
        .frame(width: contentWidth)
    }

    private func slotRow(contentWidth: CGFloat) -> some View {
        HStack(spacing: 8) {
            ForEach(0 ..< PresetArpSettings.slotCount, id: \.self) { index in
                SequencerSlotButton(
                    index: index,
                    isSelected: viewModel.arpSettings.selectedSlotIndex == index,
                    hasContent: !viewModel.arpSettings.slots[index].isEmpty,
                    width: nil,
                    height: 44,
                    cornerRadius: 10,
                    action: { viewModel.selectArpSlot(index) }
                )
            }
        }
        .frame(width: contentWidth)
    }

    private func stepGrid(contentWidth: CGFloat) -> some View {
        let labelWidth: CGFloat = 18
        let gridWidth = contentWidth - labelWidth - 8
        let cellWidth = floor(
            (gridWidth - Self.stepSpacing * CGFloat(ArpPatternSlot.stepCount - 1)) / CGFloat(ArpPatternSlot.stepCount)
        )
        let slot = viewModel.arpSettings.selectedSlot

        return VStack(spacing: 6) {
            ForEach(0 ..< ArpPatternSlot.voiceCount, id: \.self) { voice in
                HStack(spacing: 8) {
                    Text(Self.voiceLabels[voice])
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(JChordTheme.muted)
                        .frame(width: labelWidth, alignment: .center)

                    HStack(spacing: Self.stepSpacing) {
                        ForEach(0 ..< ArpPatternSlot.stepCount, id: \.self) { step in
                            stepCell(
                                isOn: slot.steps[voice][step],
                                isBeatHead: step % 4 == 0,
                                width: cellWidth
                            ) {
                                viewModel.toggleArpStep(voice: voice, step: step)
                            }
                        }
                    }
                }
            }
        }
        .frame(width: contentWidth)
    }

    private func stepCell(
        isOn: Bool,
        isBeatHead: Bool,
        width: CGFloat,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(
                    isOn
                        ? AnyShapeStyle(JPadChromeTheme.buttonIdleFill)
                        : AnyShapeStyle(Color.white.opacity(isBeatHead ? 0.1 : 0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(
                            isOn ? JPadChromeTheme.buttonIdleBorder : Color.white.opacity(0.25),
                            lineWidth: 1
                        )
                )
                .frame(width: width, height: max(34, width * 1.5))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func keyRow(contentWidth: CGFloat) -> some View {
        HStack {
            Spacer(minLength: 0)
            HStack(spacing: 10) {
                editorFieldLabel(L10n.string("main.arp.base_key"))
                JChordValueWheelPicker(
                    values: Array(PresetArpSettings.baseKeyRange.reversed()),
                    value: Binding(
                        get: { Int(viewModel.arpSettings.baseKey) },
                        set: { viewModel.updateArpBaseKey($0) }
                    ),
                    width: 76,
                    height: 36,
                    displayText: { MidiNoteFormatter.format(UInt8(clamping: $0)) }
                )
            }
        }
        .frame(width: contentWidth)
    }

    private func editorFieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .heavy))
            .foregroundStyle(JChordTheme.muted)
    }
}
