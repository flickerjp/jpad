import SwiftUI

/// UI 1.1: チップなし。Key 選択 → ADD/DEL。OCT+NOTE / 12鍵 / ROOT+操作 / CANCEL+SET。
/// 左上の LABEL / KEYS で画面切替。パネル幅: 縦最大 360pt / 横最大 560pt（左右 10pt マージン）。
struct PadKeyInputEditorSheetV11: View {
    @ObservedObject var viewModel: PadEditorViewModel
    @ObservedObject var midiService: MidiOutputService
    let padLayout: JChordPadLayout
    let metrics: PadEditorMetrics
    let showsCancelButton: Bool
    let onSet: () -> Void
    let onCancel: () -> Void

    @State private var soundingRoot: String?
    @State private var soundingPreviewMidiNote: UInt8?
    @FocusState private var isLabelFieldFocused: Bool

    private var headerControlSide: CGFloat {
        metrics.v11CornerChipHeight
    }

    var body: some View {
        VStack(alignment: .leading, spacing: metrics.v11PopupRowSpacing) {
            switch viewModel.v11PopupScreen {
            case .notes:
                notesInputContent
            case .label:
                labelEditorContent
            }
        }
        .frame(width: metrics.notePopupWidth, height: metrics.v11PopupBodyHeight, alignment: .topLeading)
        .padding(metrics.notePopupPadding)
        .fixedSize(horizontal: false, vertical: true)
        .clipped()
        .jChordPopupPanelChrome(cornerRadius: 18)
        .scrollDismissesKeyboard(.never)
        .onChange(of: viewModel.v11PopupScreen) { _, screen in
            if screen == .label {
                stopSingleNotePreview()
                isLabelFieldFocused = true
            } else {
                isLabelFieldFocused = false
            }
        }
        .task(id: viewModel.v11PopupScreen) {
            guard viewModel.v11PopupScreen == .notes else { return }
            midiService.startNoteCapture { [weak viewModel] batch in
                guard let viewModel else { return }
                viewModel.appendMidiNotesToChordKeys(batch)
            }
            defer {
                midiService.stopNoteCapture()
            }
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(1))
                } catch {
                    break
                }
            }
        }
    }

    // MARK: - Notes input

    private var notesInputContent: some View {
        VStack(alignment: .leading, spacing: metrics.v11PopupRowSpacing) {
            octaveAndNoteRow
                .frame(height: metrics.v11CornerChipHeight)

            PadEditorRootKeyboardView(
                metrics: metrics,
                selectedRoot: viewModel.selectedKeyRoot,
                registeredRootsInZone: viewModel.registeredRootsInCurrentOctave,
                soundingRoot: soundingRoot,
                onSelectRoot: { viewModel.selectKeyRootOnly($0) },
                onRootSoundingChanged: { root, isPressed in
                    handleRootSounding(root: root, isPressed: isPressed)
                },
                style: .v11,
                keyWidth: metrics.popupRootKeyWidth,
                keySpacing: metrics.popupRootKeySpacing,
                panelHorizontalPadding: 8,
                panelVerticalPadding: 8
            )
            .frame(maxWidth: metrics.v11PopupInnerWidth, alignment: .center)
            .frame(height: metrics.v11PopupKeyboardHeight)

            rootActionRow
                .frame(height: metrics.controlHeight)
                .frame(maxWidth: metrics.v11PopupInnerWidth, alignment: .leading)

            popupFooterButtons(
                leadingTitle: L10n.string("pad_editor.cancel"),
                leadingIsPrimary: false,
                leadingAction: onCancel
            )
        }
    }

    // MARK: - Label editor

    private var labelEditorContent: some View {
        VStack(alignment: .leading, spacing: metrics.v11PopupRowSpacing) {
            labelKeysRow
                .frame(height: metrics.v11CornerChipHeight)

            labelMiddleSection
                .frame(height: metrics.v11PopupMiddleHeight)

            popupFooterButtons(
                leadingTitle: L10n.string("pad_editor.cancel"),
                leadingIsPrimary: false,
                leadingAction: onCancel
            )
        }
    }

    /// KEYS のみ（INPUT NOTE の LABEL 行と同じ位置）
    private var labelKeysRow: some View {
        HStack(spacing: 0) {
            cornerChipButton(
                title: L10n.string("pad_editor_v11.keys"),
                height: headerControlSide,
                action: { viewModel.showV11NotesInput() }
            )
            .accessibilityLabel(L10n.string("pad_editor_v11.back_to_notes.accessibility"))

            Spacer(minLength: 0)

            Color.clear
                .frame(width: headerControlSide, height: headerControlSide)
        }
    }

    /// KEYS の下: 見出し列 + 入力/チップ列（左ライン揃え）
    private var labelMiddleSection: some View {
        let labelWidth = metrics.v11SectionLabelWidth
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                Text(L10n.string("pad_editor_v11.label"))
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(JChordTheme.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(width: labelWidth, alignment: .leading)

                labelTextField
                    .frame(maxWidth: .infinity)
            }

            HStack(alignment: .top, spacing: 8) {
                Text(L10n.string("pad_editor_v11.candidates"))
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(JChordTheme.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .frame(width: labelWidth, alignment: .leading)
                    .padding(.top, 2)

                labelCandidatesRow
                    .frame(minHeight: metrics.controlHeight)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var labelTextField: some View {
        let fieldShape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        return ZStack(alignment: .leading) {
            if viewModel.label.isEmpty {
                Text("[Chord name]")
                    .font(.system(size: metrics.labelFontSize, weight: .heavy))
                    .foregroundStyle(JChordTheme.muted.opacity(0.55))
                    .allowsHitTesting(false)
            }

            TextField(
                "",
                text: Binding(
                    get: { viewModel.label },
                    set: { viewModel.updateLabel($0) }
                )
            )
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .font(.system(size: metrics.labelFontSize, weight: .heavy))
            .foregroundStyle(JChordTheme.text)
            .focused($isLabelFieldFocused)
            .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .frame(height: metrics.controlHeight, alignment: .center)
        .background(Color.white.opacity(0.04), in: fieldShape)
        .overlay(
            fieldShape.strokeBorder(
                isLabelFieldFocused ? Color.white.opacity(0.22) : Color.white.opacity(0.1),
                lineWidth: 1
            )
        )
    }

    private var labelCandidatesRow: some View {
        let candidates = viewModel.labelEditorCandidates
        return Group {
            if candidates.isEmpty {
                Text("—")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(JChordTheme.muted)
                    .frame(height: metrics.controlHeight, alignment: .leading)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(candidates, id: \.self) { candidate in
                            Button(candidate) {
                                viewModel.applyCandidate(candidate)
                            }
                            .font(.caption.weight(.bold))
                            .foregroundStyle(JChordTheme.text)
                            .padding(.horizontal, 12)
                            .frame(height: metrics.controlHeight)
                            .background(
                                viewModel.label == candidate
                                    ? Color.white.opacity(0.12)
                                    : Color.white.opacity(0.05),
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                            )
                        }
                    }
                    .fixedSize(horizontal: true, vertical: false)
                }
                .frame(height: metrics.controlHeight)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Shared footer

    private var v11FooterButtonWidth: CGFloat {
        metrics.v11PopupFooterButtonWidth(gridSpacing: padLayout.gridSpacing)
    }

    @ViewBuilder
    private func popupFooterButtons(
        leadingTitle: String,
        leadingIsPrimary: Bool,
        leadingAction: @escaping () -> Void
    ) -> some View {
        if showsCancelButton {
            HStack(spacing: padLayout.gridSpacing) {
                JPadChromeDockButton(
                    title: leadingTitle,
                    style: .outline,
                    width: v11FooterButtonWidth,
                    height: metrics.actionButtonHeight,
                    action: leadingAction
                )

                JPadChromeDockButton(
                    title: L10n.string("pad_editor.set"),
                    style: .accentToggle,
                    isOn: true,
                    width: v11FooterButtonWidth,
                    height: metrics.actionButtonHeight,
                    action: onSet
                )
            }
            .frame(width: metrics.v11PopupInnerWidth, height: metrics.actionButtonHeight)
        } else {
            JPadChromeDockButton(
                title: L10n.string("pad_editor.set"),
                style: .accentToggle,
                isOn: true,
                width: v11FooterButtonWidth,
                height: metrics.actionButtonHeight,
                action: onSet
            )
            .frame(width: metrics.v11PopupInnerWidth, height: metrics.actionButtonHeight)
        }
    }

    // MARK: - Notes rows

    private var rootActionRow: some View {
        HStack(spacing: 10) {
            Button {
                viewModel.assignRootFromSelectedKey()
            } label: {
                actionChipLabel(
                    L10n.string("pad_editor_v11.root"),
                    isActive: true
                )
            }
            .buttonStyle(.plain)
            .disabled(viewModel.selectedKeyRoot == nil)

            if let bassLabel = viewModel.v11BassNotesLabel {
                Text(bassLabel)
                    .font(.subheadline.weight(.light))
                    .foregroundStyle(JChordTheme.midiDeviceSelectedForeground)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 4)

            Button {
                viewModel.registerSelectedKeyAtCurrentOctave()
            } label: {
                utilityActionLabel(L10n.string("pad_editor_v11.add"), width: metrics.v11UtilityChipWidth)
            }
            .buttonStyle(.plain)

            Button {
                viewModel.deleteSelectedKeyAtCurrentOctave()
            } label: {
                utilityActionLabel(L10n.string("pad_editor_v11.del"), width: metrics.v11UtilityChipWidth)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.selectedKeyRoot == nil)

            Button {
                viewModel.clearAllEditingNotes()
            } label: {
                utilityActionLabel(L10n.string("pad_editor_v11.clear"), width: metrics.v11UtilityChipWidth)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
    }

    private func actionChipLabel(_ title: String, isActive: Bool = false) -> some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        return Text(title)
            .font(.caption.weight(.heavy))
            .foregroundStyle(isActive ? JChordTheme.text : JChordTheme.muted)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .padding(.horizontal, 8)
            .frame(minWidth: metrics.v11RootChipWidth)
            .frame(height: metrics.controlHeight)
            .background(
                isActive ? Color.white.opacity(0.12) : Color.white.opacity(0.06),
                in: shape
            )
    }

    private func utilityActionLabel(_ title: String, width: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        return Text(title)
            .font(.caption.weight(.heavy))
            .foregroundStyle(JChordTheme.text.opacity(0.92))
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .padding(.horizontal, 6)
            .frame(minWidth: width)
            .frame(height: metrics.controlHeight)
            .background(JChordTheme.v11UtilityButtonBackground, in: shape)
            .overlay(shape.strokeBorder(JChordTheme.v11UtilityButtonBorder, lineWidth: 1))
    }

    /// LABEL / KEYS — 固定幅でクリップしない
    private func cornerChipButton(
        title: String,
        height: CGFloat,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
            Text(title)
                .font(.caption2.weight(.heavy))
                .foregroundStyle(JChordTheme.text.opacity(0.92))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 8)
                .frame(minWidth: metrics.v11CornerChipMinWidth)
                .frame(height: height)
                .background(JChordTheme.v11UtilityButtonBackground, in: shape)
                .overlay(shape.strokeBorder(JChordTheme.v11UtilityButtonBorder, lineWidth: 1))
                .fixedSize(horizontal: true, vertical: false)
        }
        .buttonStyle(.plain)
    }

    private var octaveAndNoteRow: some View {
        let noteSide = headerControlSide
        return HStack(spacing: 0) {
            cornerChipButton(
                title: L10n.string("pad_editor_v11.label"),
                height: noteSide,
                action: { viewModel.showV11LabelEditor() }
            )
            .accessibilityLabel(L10n.string("pad_editor_v11.edit_label.accessibility"))

            Spacer(minLength: 0)
            HStack(spacing: 6) {
                octaveShiftIndicator(viewModel.lowerOctaveShiftIndicator)
                octaveStepButton(title: "<", canStep: viewModel.editingOctave > PadEditorViewModel.keyInputOctaveMin) {
                    viewModel.editingOctave -= 1
                    viewModel.clampEditingOctave()
                }
                Text(viewModel.octaveZoneLabel)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(JChordTheme.text)
                    .frame(minWidth: 36)
                octaveStepButton(title: ">", canStep: viewModel.editingOctave < PadEditorViewModel.keyInputOctaveMax) {
                    viewModel.editingOctave += 1
                    viewModel.clampEditingOctave()
                }
                octaveShiftIndicator(viewModel.upperOctaveShiftIndicator)
            }
            Spacer(minLength: 0)
            previewNoteButton
                .frame(width: metrics.actionButtonHeight, height: metrics.actionButtonHeight)
        }
    }

    private func octaveShiftIndicator(_ state: PadEditorViewModel.OctaveShiftIndicatorState) -> some View {
        let color: Color = switch state {
        case .inactive:
            Color.white.opacity(0.12)
        case .oneOctaveAway:
            JChordTheme.octaveShiftNearIndicator
        case .twoOrMoreOctavesAway:
            JChordTheme.octaveShiftFarIndicator
        }
        return Circle()
            .fill(color)
            .frame(width: 8, height: 8)
    }

    private func octaveStepButton(title: String, canStep: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.title2.weight(.bold))
                .foregroundStyle(JChordTheme.text.opacity(canStep ? 1 : 0.45))
                .frame(width: 36, height: metrics.controlHeight)
        }
        .buttonStyle(.plain)
        .allowsHitTesting(canStep)
    }

    private var previewNoteButton: some View {
        let notes = viewModel.previewNotesForHold
        let midiReady = midiService.hasActiveMidiOutput
        return PadEditorPianoPreviewButton(
            usesMidiAccentIdle: midiReady,
            size: metrics.actionButtonHeight
        ) { isPressed in
            guard !notes.isEmpty else { return }
            if isPressed {
                stopSingleNotePreview()
            }
            let pad = viewModel.draftPadFromEditing()
            if isPressed {
                midiService.sendPadOn(pad)
            } else {
                midiService.sendPadOff(pad)
            }
        }
        .accessibilityLabel(L10n.string("pad_editor.preview_note.accessibility"))
    }

    private func handleRootSounding(root: String, isPressed: Bool) {
        if isPressed {
            soundingRoot = root
            guard midiService.hasActiveMidiOutput,
                  let note = viewModel.midiNote(forRoot: root) else { return }
            if soundingPreviewMidiNote != note {
                if let previous = soundingPreviewMidiNote {
                    midiService.sendPreviewNoteOff(previous)
                }
                soundingPreviewMidiNote = note
                midiService.sendPreviewNoteOn(note)
            }
        } else {
            soundingRoot = nil
            if let note = soundingPreviewMidiNote {
                midiService.sendPreviewNoteOff(note)
                soundingPreviewMidiNote = nil
            }
        }
    }

    private func stopSingleNotePreview() {
        soundingRoot = nil
        if let note = soundingPreviewMidiNote {
            midiService.sendPreviewNoteOff(note)
            soundingPreviewMidiNote = nil
        }
    }
}

/// 鍵盤アイコン試聴（EDIT パッド右上と同じ TinyTone オレンジ＋白鍵盤）。
private struct PadEditorPianoPreviewButton: View {
    let usesMidiAccentIdle: Bool
    let size: CGFloat
    let onPressChanged: (Bool) -> Void

    @State private var isPressed = false

    var body: some View {
        let shape = RoundedRectangle(
            cornerRadius: JPadPianoChromeStyle.cornerRadius(for: size),
            style: .continuous
        )

        JPadPianoChromeIcon(
            size: size,
            isPressed: isPressed,
            isEnabled: usesMidiAccentIdle
        )
        .contentShape(shape)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard usesMidiAccentIdle, !isPressed else { return }
                    isPressed = true
                    onPressChanged(true)
                }
                .onEnded { _ in
                    releaseIfNeeded()
                }
        )
        .onDisappear {
            releaseIfNeeded()
        }
    }

    private func releaseIfNeeded() {
        guard isPressed else { return }
        isPressed = false
        onPressChanged(false)
    }
}
