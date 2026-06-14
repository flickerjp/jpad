import SwiftUI

// MARK: - 共通: パターンスロットボタン (1〜4)

struct SequencerSlotButton: View {
    let index: Int
    let isSelected: Bool
    let hasContent: Bool
    /// RIFF が ON、または SEQ が再生（ラッチ）中で、このスロットが鳴っている状態。
    var isActive: Bool = false
    var width: CGFloat?
    var height: CGFloat
    var cornerRadius: CGFloat
    let action: () -> Void

    private var highlighted: Bool { isSelected || isActive }

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
                isActive
                    ? JPadOrangeChromeStyle.foreground(isPressed: false, isAccentOn: true)
                    : (isSelected ? JPadChromeTheme.buttonLabelFilled : Color.white.opacity(0.9))
            )
            .frame(maxWidth: .infinity, minHeight: height, alignment: .center)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(backgroundStyle)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        highlighted ? JPadChromeTheme.buttonIdleBorder : Color.white.opacity(0.85),
                        lineWidth: 1.2
                    )
            )
        }
        .buttonStyle(.plain)
        .frame(width: width)
        .jChordGentlePulse(isActive)
        .accessibilityLabel("Pattern \(index + 1)")
        .accessibilityAddTraits(highlighted ? .isSelected : [])
    }

    private var backgroundStyle: AnyShapeStyle {
        if isActive {
            return JPadOrangeChromeStyle.background(isPressed: false, isAccentOn: true)
        }
        if isSelected {
            return AnyShapeStyle(JPadChromeTheme.buttonIdleFill)
        }
        return AnyShapeStyle(Color.clear)
    }
}

// MARK: - RIFF 縦表示コントロール

struct RiffControlRows: View {
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
                ForEach(0 ..< PresetRiffSettings.slotCount, id: \.self) { index in
                    SequencerSlotButton(
                        index: index,
                        isSelected: viewModel.riffSettings.selectedSlotIndex == index,
                        hasContent: !viewModel.riffSettings.slots[index].isEmpty,
                        isActive: viewModel.isRiffSlotActive(index),
                        width: topCellWidth,
                        height: slotHeight,
                        cornerRadius: min(layout.padCornerRadius, slotHeight * 0.32),
                        action: { viewModel.toggleRiffSlot(index) }
                    )
                }

                SequencerGateWheel(
                    gate: Binding(
                        get: { Int((viewModel.riffSettings.selectedSlot.gate * 100).rounded()) },
                        set: { viewModel.updateRiffGate(Double($0) / 100) }
                    ),
                    width: topCellWidth,
                    height: slotHeight
                )
            }
            .frame(width: layout.gridWidth)

            RiffStepDisplay(
                slot: viewModel.isRiffDoubleEditEnabled
                    ? viewModel.riffSettings.selectedSlot.maskedRepeatingFirstHalf()
                    : viewModel.riffSettings.selectedSlot,
                currentRawStep: viewModel.sequencerEngine.riffCurrentRawStep,
                width: layout.gridWidth
            )

            HStack(spacing: layout.gridSpacing) {
                JPadChromeDockButton(
                    title: L10n.string("main.riff.edit"),
                    style: .outline,
                    fontSize: 12,
                    width: transportButtonWidth,
                    height: transportHeight,
                    action: { viewModel.presentRiffEditor() }
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
                        isActive: viewModel.isSeqSlotPlaying(index),
                        width: topCellWidth,
                        height: slotHeight,
                        cornerRadius: min(layout.padCornerRadius, slotHeight * 0.32),
                        action: { viewModel.toggleSeqSlot(index) }
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
            width: floor((layout.gridWidth - layout.gridSpacing * 4) / 5),
            height: transportHeight,
            action: action
        )
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
    }
}

// MARK: - RIFF ステップ表示 (16 セル)

struct RiffStepDisplay: View {
    let slot: RiffPatternSlot
    let currentRawStep: Int?
    let width: CGFloat

    private static let cellSpacing: CGFloat = 3
    private static let inputStepColor = Color.white.opacity(0.58)
    private static let tieStepColor = Color.white.opacity(0.34)

    var body: some View {
        let cellWidth = floor((width - Self.cellSpacing * CGFloat(RiffPatternSlot.stepCount - 1)) / CGFloat(RiffPatternSlot.stepCount))
        HStack(spacing: Self.cellSpacing) {
            ForEach(0 ..< RiffPatternSlot.stepCount, id: \.self) { step in
                stepCell(at: step, cellWidth: cellWidth)
            }
        }
        .frame(width: width)
    }

    private func stepCell(at step: Int, cellWidth: CGFloat) -> some View {
        let isPlayingHere = currentRawStep == step
        let activeVoices = (0 ..< RiffPatternSlot.voiceCount).filter { voice in
            slot.steps.indices.contains(voice)
                && slot.steps[voice].indices.contains(step)
                && slot.steps[voice][step]
        }

        return VStack(spacing: 2) {
            ForEach(0 ..< RiffPatternSlot.voiceCount, id: \.self) { voice in
                ZStack {
                    Capsule()
                        .fill(
                            slot.isTie(voice: voice, step: step)
                                ? Self.tieStepColor
                                : (activeVoices.contains(voice) ? Self.inputStepColor : Color.white.opacity(0.12))
                        )
                        .frame(width: max(5, cellWidth * 0.48), height: 3)
                }
            }
        }
        .frame(width: cellWidth, height: max(22, cellWidth * 1.05))
        .background(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(
                    isPlayingHere
                        ? AnyShapeStyle(JPadChromeTheme.buttonIdleFill)
                        : AnyShapeStyle(Color.white.opacity(step % 4 == 0 ? 0.08 : 0.04))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .strokeBorder(
                    isPlayingHere
                        ? JPadChromeTheme.buttonIdleBorder
                        : Color.white.opacity(activeVoices.isEmpty ? 0.2 : 0.35),
                    lineWidth: isPlayingHere ? 1.4 : 1
                )
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

struct RiffLandscapePanel: View {
    @ObservedObject var viewModel: MainViewModel
    let layout: JChordPadLayout

    var body: some View {
        VStack(spacing: layout.gridSpacing) {
            ForEach(0 ..< PresetRiffSettings.slotCount, id: \.self) { index in
                SequencerSlotButton(
                    index: index,
                    isSelected: viewModel.riffSettings.selectedSlotIndex == index,
                    hasContent: !viewModel.riffSettings.slots[index].isEmpty,
                    isActive: viewModel.isRiffSlotActive(index),
                    width: layout.landscapeControlPanelWidth,
                    height: 44,
                    cornerRadius: 10,
                    action: { viewModel.toggleRiffSlot(index) }
                )
            }

            SequencerGateWheel(
                gate: Binding(
                    get: { Int((viewModel.riffSettings.selectedSlot.gate * 100).rounded()) },
                    set: { viewModel.updateRiffGate(Double($0) / 100) }
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
                    isActive: viewModel.isSeqSlotPlaying(index),
                    width: layout.landscapeControlPanelWidth,
                    height: 44,
                    cornerRadius: 10,
                    action: { viewModel.toggleSeqSlot(index) }
                )
            }

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

// MARK: - RIFF パターンエディタ (パッドエリアも使う全面オーバーレイ)

struct RiffPatternEditorOverlay: View {
    @ObservedObject var viewModel: MainViewModel
    @State private var dragStepValue: Bool?
    @State private var dragTieValue: Bool?
    @State private var dragTieStart: (voice: Int, step: Int)?

    private static let stepSpacing: CGFloat = 3
    private static let voiceRowSpacing: CGFloat = 6
    private static let sectionSpacing: CGFloat = 12
    private static let stepLabelHeight: CGFloat = 14
    private static let stepsPerRow = 8
    private static let voiceLabels = ["U", "M1", "M2", "L"]
    private static let stepRowLabels = ["01-08", "09-16"]
    private static let editButtonWidth: CGFloat = 67
    private static let editButtonHeight: CGFloat = 36
    private static let editButtonFontSize: CGFloat = 12
    private static let doubleButtonWidth: CGFloat = 60
    private static let keyControlWidth: CGFloat = 76
    private static let offsetControlWidth: CGFloat = 60
    private static let inputStepGradient = LinearGradient(
        colors: [
            Color.white.opacity(0.66),
            Color.white.opacity(0.42),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    private static let tieStepGradient = LinearGradient(
        colors: [
            Color.white.opacity(0.44),
            Color.white.opacity(0.24),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

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
            Text(L10n.string("main.riff.editor_title"))
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(JChordTheme.text)

            Spacer(minLength: 0)

            JPadChromeDockButton(
                title: L10n.string("main.done"),
                style: .accentToggle,
                isOn: true,
                width: 88,
                height: 34,
                action: { viewModel.dismissRiffEditor() }
            )
        }
        .frame(width: contentWidth)
    }

    private func slotRow(contentWidth: CGFloat) -> some View {
        HStack(spacing: 8) {
            ForEach(0 ..< PresetRiffSettings.slotCount, id: \.self) { index in
                SequencerSlotButton(
                    index: index,
                    isSelected: viewModel.riffSettings.selectedSlotIndex == index,
                    hasContent: !viewModel.riffSettings.slots[index].isEmpty,
                    width: nil,
                    height: 44,
                    cornerRadius: 10,
                    action: { viewModel.selectRiffSlot(index) }
                )
            }
        }
        .frame(width: contentWidth)
    }

    private func stepGrid(contentWidth: CGFloat) -> some View {
        let labelWidth: CGFloat = 24
        let gridWidth = contentWidth - labelWidth - 8
        let cellWidth = floor(
            (gridWidth - Self.stepSpacing * CGFloat(Self.stepsPerRow - 1)) / CGFloat(Self.stepsPerRow)
        )
        let cellHeight = stepCellHeight(width: cellWidth)
        let sectionHeight = Self.stepLabelHeight
            + Self.voiceRowSpacing
            + CGFloat(RiffPatternSlot.voiceCount) * cellHeight
            + CGFloat(RiffPatternSlot.voiceCount - 1) * Self.voiceRowSpacing
        let gridHeight = CGFloat(Self.stepRowLabels.count) * sectionHeight
            + CGFloat(Self.stepRowLabels.count - 1) * Self.sectionSpacing
        let slot = viewModel.riffSettings.selectedSlot

        return ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: Self.sectionSpacing) {
                ForEach(0 ..< Self.stepRowLabels.count, id: \.self) { row in
                    VStack(alignment: .leading, spacing: Self.voiceRowSpacing) {
                        Text(Self.stepRowLabels[row])
                            .font(.system(size: 11, weight: .heavy))
                            .monospacedDigit()
                            .foregroundStyle(JChordTheme.muted.opacity(0.9))
                            .frame(width: contentWidth, height: Self.stepLabelHeight, alignment: .leading)

                        ForEach(0 ..< RiffPatternSlot.voiceCount, id: \.self) { voice in
                            HStack(spacing: 8) {
                                Text(Self.voiceLabels[voice])
                                    .font(.system(size: 13, weight: .heavy))
                                    .foregroundStyle(JChordTheme.muted)
                                    .frame(width: labelWidth, height: cellHeight, alignment: .center)

                                riffStepRow(
                                    slot: slot,
                                    voice: voice,
                                    row: row,
                                    cellWidth: cellWidth,
                                    gridWidth: gridWidth
                                )
                            }
                        }
                    }
                }
            }

            Color.clear
                .frame(width: contentWidth, height: gridHeight)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            applyRiffGridDrag(
                                value: value,
                                slot: slot,
                                labelWidth: labelWidth,
                                cellWidth: cellWidth,
                                cellHeight: cellHeight,
                                sectionHeight: sectionHeight
                            )
                        }
                        .onEnded { _ in
                            dragStepValue = nil
                            dragTieValue = nil
                            dragTieStart = nil
                            viewModel.endRiffEditUndoGroup()
                        }
                )
        }
        .frame(width: contentWidth, height: gridHeight)
    }

    private func riffStepRow(
        slot: RiffPatternSlot,
        voice: Int,
        row: Int,
        cellWidth: CGFloat,
        gridWidth: CGFloat
    ) -> some View {
        let displaySlot = viewModel.isRiffDoubleEditEnabled
            ? slot.maskedRepeatingFirstHalf()
            : slot

        return HStack(spacing: Self.stepSpacing) {
            ForEach(0 ..< Self.stepsPerRow, id: \.self) { column in
                let step = row * Self.stepsPerRow + column
                stepCell(
                    isOn: displaySlot.steps[voice][step],
                    isTie: displaySlot.isTie(voice: voice, step: step),
                    isTieGroup: isTieGroupCell(slot: displaySlot, voice: voice, step: step),
                    isLocked: viewModel.isRiffDoubleEditEnabled && step >= RiffPatternSlot.stepCount / 2,
                    isBeatHead: step % 4 == 0,
                    width: cellWidth
                )
            }
        }
        .frame(width: gridWidth, height: stepCellHeight(width: cellWidth))
    }

    private func applyRiffGridDrag(
        value: DragGesture.Value,
        slot: RiffPatternSlot,
        labelWidth: CGFloat,
        cellWidth: CGFloat,
        cellHeight: CGFloat,
        sectionHeight: CGFloat
    ) {
        let gridX = value.location.x - labelWidth - 8
        guard gridX >= 0 else { return }
        let columnStride = cellWidth + Self.stepSpacing
        let rawColumn = Int((gridX / columnStride).rounded(.down))
        let column = max(0, min(Self.stepsPerRow - 1, rawColumn))

        let sectionStride = sectionHeight + Self.sectionSpacing
        let rawRow = Int((value.location.y / sectionStride).rounded(.down))
        guard (0 ..< Self.stepRowLabels.count).contains(rawRow) else { return }
        let sectionY = value.location.y - CGFloat(rawRow) * sectionStride
        let voiceAreaY = sectionY - Self.stepLabelHeight - Self.voiceRowSpacing
        guard voiceAreaY >= 0 else { return }

        let voiceStride = cellHeight + Self.voiceRowSpacing
        let voice = Int((voiceAreaY / voiceStride).rounded(.down))
        guard (0 ..< RiffPatternSlot.voiceCount).contains(voice),
              voiceAreaY - CGFloat(voice) * voiceStride <= cellHeight
        else { return }

        let row = rawRow
        let step = row * Self.stepsPerRow + column
        guard slot.steps.indices.contains(voice),
              slot.steps[voice].indices.contains(step)
        else { return }
        guard !viewModel.isRiffDoubleEditEnabled || step < RiffPatternSlot.stepCount / 2 else { return }

        if viewModel.isRiffTieEditing {
            if dragTieValue == nil {
                viewModel.beginRiffEditUndoGroup()
                dragTieStart = (voice, step)
            }
            let targetValue = dragTieValue ?? !slot.isTie(voice: voice, step: step)
            dragTieValue = targetValue
            applyRiffTieDrag(
                slot: slot,
                voice: voice,
                step: step,
                isOn: targetValue
            )
        } else {
            if dragStepValue == nil {
                viewModel.beginRiffEditUndoGroup()
            }
            let targetValue = dragStepValue ?? !slot.steps[voice][step]
            dragStepValue = targetValue
            viewModel.setRiffStep(voice: voice, step: step, isOn: targetValue, recordsUndo: false)
        }
    }

    private func applyRiffTieDrag(
        slot: RiffPatternSlot,
        voice: Int,
        step: Int,
        isOn: Bool
    ) {
        guard let start = dragTieStart,
              start.voice == voice,
              slot.steps.indices.contains(voice),
              slot.steps[voice].indices.contains(step),
              slot.steps[voice][step]
        else { return }

        let sameRow = start.step / Self.stepsPerRow == step / Self.stepsPerRow
        if sameRow, step > start.step {
            for targetStep in start.step ... step {
                guard slot.steps[voice].indices.contains(targetStep),
                      slot.steps[voice][targetStep]
                else { continue }
                viewModel.setRiffTie(
                    voice: voice,
                    step: targetStep,
                    isOn: targetStep != start.step,
                    recordsUndo: false
                )
            }
            return
        }

        if sameRow, step < start.step {
            for targetStep in step ... start.step {
                guard slot.steps[voice].indices.contains(targetStep),
                      slot.steps[voice][targetStep],
                      slot.canTie(voice: voice, step: targetStep)
                else { continue }
                viewModel.setRiffTie(
                    voice: voice,
                    step: targetStep,
                    isOn: true,
                    recordsUndo: false
                )
            }
            return
        }

        guard slot.canTie(voice: voice, step: step) else { return }
        viewModel.setRiffTie(voice: voice, step: step, isOn: isOn, recordsUndo: false)
    }

    private func stepCell(
        isOn: Bool,
        isTie: Bool,
        isTieGroup: Bool,
        isLocked: Bool,
        isBeatHead: Bool,
        width: CGFloat
    ) -> some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(stepCellFill(isOn: isOn, isTie: isTie, isBeatHead: isBeatHead))
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(
                        isOn ? Color.white.opacity(0.42) : Color.white.opacity(0.25),
                        lineWidth: 1
                    )
            )
            .overlay(alignment: .bottom) {
                if isTieGroup {
                    Rectangle()
                        .fill(Color.white.opacity(0.72))
                        .frame(height: 2)
                        .padding(.horizontal, 5)
                        .padding(.bottom, 5)
                }
            }
            .frame(width: width, height: stepCellHeight(width: width))
            .opacity(isLocked ? 0.58 : 1)
            .contentShape(Rectangle())
    }

    private func stepCellFill(isOn: Bool, isTie: Bool, isBeatHead: Bool) -> AnyShapeStyle {
        if isTie {
            return AnyShapeStyle(Self.tieStepGradient)
        }
        if isOn {
            return AnyShapeStyle(Self.inputStepGradient)
        }
        return AnyShapeStyle(Color.white.opacity(isBeatHead ? 0.1 : 0.05))
    }

    private func isTieGroupCell(slot: RiffPatternSlot, voice: Int, step: Int) -> Bool {
        guard slot.steps.indices.contains(voice),
              slot.steps[voice].indices.contains(step),
              slot.steps[voice][step]
        else { return false }
        let nextStep = (step + 1) % RiffPatternSlot.stepCount
        return slot.isTie(voice: voice, step: step)
            || slot.isTie(voice: voice, step: nextStep)
    }

    private func stepCellHeight(width: CGFloat) -> CGFloat {
        max(30, min(38, width * 0.86))
    }

    private func keyRow(contentWidth: CGFloat) -> some View {
        HStack(alignment: .bottom) {
            HStack(spacing: 8) {
                JPadChromeDockButton(
                    title: L10n.string("main.riff.tie"),
                    style: .accentToggle,
                    isOn: viewModel.isRiffTieEditing,
                    fontSize: Self.editButtonFontSize,
                    width: Self.editButtonWidth,
                    height: Self.editButtonHeight,
                    action: { viewModel.toggleRiffTieEditing() }
                )

                JPadChromeDockButton(
                    title: L10n.string("main.riff.undo"),
                    style: .outline,
                    fontSize: Self.editButtonFontSize,
                    width: Self.editButtonWidth,
                    height: Self.editButtonHeight,
                    action: { viewModel.undoRiffEdit() }
                )
                .disabled(!viewModel.canUndoRiffEdit)
                .opacity(viewModel.canUndoRiffEdit ? 1 : 0.35)

            }

            Spacer(minLength: 0)

            HStack(alignment: .bottom, spacing: 8) {
                JPadChromeDockButton(
                    title: L10n.string("main.riff.x2"),
                    style: .accentToggle,
                    isOn: viewModel.isRiffDoubleEditEnabled,
                    fontSize: Self.editButtonFontSize,
                    width: Self.doubleButtonWidth,
                    height: Self.editButtonHeight,
                    action: { viewModel.toggleRiffDoubleEdit() }
                )

                VStack(spacing: 2) {
                    editorFieldLabel(L10n.string("main.riff.base_key"))
                    JChordValueWheelPicker(
                        values: Array(PresetRiffSettings.baseKeyRange.reversed()),
                        value: Binding(
                            get: { Int(viewModel.riffSettings.baseKey) },
                            set: { viewModel.updateRiffBaseKey($0) }
                        ),
                        width: Self.keyControlWidth,
                        height: 36,
                        displayText: { MidiNoteFormatter.format(UInt8(clamping: $0)) }
                    )
                }

                VStack(spacing: 2) {
                    editorFieldLabel(L10n.string("main.riff.offset"), width: Self.offsetControlWidth)
                    JChordValueWheelPicker(
                        values: Array(stride(from: 8, through: -8, by: -1)),
                        value: Binding(
                            get: { viewModel.clockRiffStepOffset },
                            set: { viewModel.updateClockRiffStepOffset($0) }
                        ),
                        width: Self.offsetControlWidth,
                        height: 36,
                        displayText: { $0 > 0 ? "+\($0)" : "\($0)" }
                    )
                }
            }
        }
        .frame(width: contentWidth)
        .padding(.top, 4)
    }

    private func editorFieldLabel(_ text: String, width: CGFloat = Self.keyControlWidth) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .regular))
            .foregroundStyle(JChordTheme.muted)
            .frame(width: width)
    }
}
