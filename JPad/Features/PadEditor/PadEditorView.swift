import SwiftUI

struct PadEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var midiService: MidiOutputService
    @StateObject private var viewModel: PadEditorViewModel
    @StateObject private var sectionExpansion = PadEditorSectionExpansionStore()
    @FocusState private var isLabelFieldFocused: Bool

    private let baseSectionSpacing: CGFloat = 14
    private let extraSectionSpacing: CGFloat = 20

    private let onCancel: () -> Void

    init(
        pad: PadDefinition,
        midiService: MidiOutputService,
        onSave: @escaping (PadDefinition) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.midiService = midiService
        self.onCancel = onCancel
        _viewModel = StateObject(
            wrappedValue: PadEditorViewModel(pad: pad, onSave: onSave)
        )
    }

    var body: some View {
        GeometryReader { geometry in
            let padLayout = JChordPadLayout.make(
                size: geometry.size,
                safeArea: geometry.safeAreaInsets
            )
            let metrics = PadEditorMetrics(
                isLandscape: geometry.size.width > geometry.size.height,
                padLayout: padLayout,
                size: geometry.size,
                safeArea: geometry.safeAreaInsets
            )
            let sectionSpacing = baseSectionSpacing + extraSectionSpacing

            ZStack {
                VStack(spacing: metrics.outerSpacing) {
                    ScrollView {
                        editorCard(
                            metrics: metrics,
                            padLayout: padLayout,
                            sectionSpacing: sectionSpacing
                        )
                            .padding(metrics.cardOuterPadding)
                    }

                    actionBar(layout: padLayout, buttonHeight: metrics.actionButtonHeight)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, padLayout.horizontalPadding)
                }
                .padding(.top, metrics.outerSpacing)
                .safeAreaPadding(.bottom, 8)

                if viewModel.isShowingNotesEditor {
                    PadEditorPopupOverlay(onBackdropTap: PadEditorUIVersion.current == .v1 ? { viewModel.cancelNotesEditor() } : nil) {
                        PadEditorNotesEditorFactory.make(
                            viewModel: viewModel,
                            midiService: midiService,
                            padLayout: padLayout,
                            metrics: metrics,
                            showsCancelButton: true,
                            onSet: { viewModel.commitNotesEditor() },
                            onCancel: { viewModel.cancelNotesEditor() }
                        )
                        .id(orientationLayoutID(isLandscape: metrics.isLandscape, width: metrics.notePopupWidth))
                    }
                    .transition(.opacity)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .animation(.easeOut(duration: 0.18), value: viewModel.isShowingNotesEditor)
        .jChordScreenBackground()
        .navigationBarBackButtonHidden(true)
        .onChange(of: viewModel.isShowingNotesEditor) { _, isShowing in
            if isShowing {
                isLabelFieldFocused = false
            } else {
                midiService.stopNoteCapture()
            }
        }
    }

    private func editorCard(
        metrics: PadEditorMetrics,
        padLayout: JChordPadLayout,
        sectionSpacing: CGFloat
    ) -> some View {
        editorSectionPanel {
            VStack(alignment: .leading, spacing: sectionSpacing) {
                VStack(alignment: .leading, spacing: baseSectionSpacing) {
                    sectionLabel(L10n.string("pad_editor.label_section"))
                    labelField(metrics: metrics)
                }

                PadEditorDisclosureSection(
                    title: L10n.string("pad_editor.root"),
                    isExpanded: $sectionExpansion.isRootExpanded
                ) {
                    rootKeyboard(metrics: metrics)
                }

                PadEditorDisclosureSection(
                    title: L10n.string("pad_editor.input_notes"),
                    isExpanded: $sectionExpansion.isInputNotesExpanded
                ) {
                    VStack(alignment: .leading, spacing: baseSectionSpacing) {
                        notesRow(metrics: metrics)
                        sectionPreviewNoteButton(
                            notes: viewModel.notes,
                            padLayout: padLayout,
                            metrics: metrics
                        )
                    }
                }
            }
        }
    }

    private func sectionPreviewNoteButton(
        notes: [UInt8],
        padLayout: JChordPadLayout,
        metrics: PadEditorMetrics
    ) -> some View {
        JChordTestNotePadButton(
            titleKey: "pad_editor.preview_note",
            appearance: .midiAccent,
            isMidiOutputActive: midiService.hasActiveMidiOutput,
            width: padLayout.cellSide,
            height: metrics.actionButtonHeight
        ) { isPressed in
            let pad = viewModel.draftPad(using: notes)
            if isPressed {
                midiService.sendPadOn(pad)
            } else {
                midiService.sendPadOff(pad)
            }
        }
        .accessibilityLabel(L10n.string("pad_editor.preview_note.accessibility"))
        .padding(.top, baseSectionSpacing)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func editorSectionPanel<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(JChordTheme.panel, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func labelField(metrics: PadEditorMetrics) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .leading) {
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
            .padding(.horizontal, 4)
            .padding(.vertical, metrics.labelVerticalPadding)
            .frame(height: metrics.labelFieldHeight, alignment: .center)

            candidatesRow(metrics: metrics)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    isLabelFieldFocused ? Color.white.opacity(0.22) : Color.white.opacity(0.1),
                    lineWidth: 1
                )
        )
    }

    @ViewBuilder
    private func labeledRow<Content: View>(
        _ title: String,
        metrics: PadEditorMetrics,
        alignment: VerticalAlignment = .top,
        @ViewBuilder content: () -> Content
    ) -> some View {
        if metrics.isLandscape {
            HStack(alignment: alignment, spacing: metrics.rowLabelSpacing) {
                rowLabel(title, width: metrics.rowLabelWidth)
                content()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            VStack(alignment: .leading, spacing: metrics.sectionLabelSpacing) {
                sectionLabel(title)
                content()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func candidatesRow(metrics: PadEditorMetrics) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.candidates, id: \.self) { candidate in
                    Button(candidate) {
                        viewModel.applyCandidate(candidate)
                    }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(JChordTheme.text)
                    .padding(.horizontal, 12)
                    .frame(height: metrics.controlHeight)
                    .background(
                        viewModel.label == candidate ? Color.white.opacity(0.12) : Color.white.opacity(0.05),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                }
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .frame(height: metrics.controlHeight)
    }

    private func notesRow(metrics: PadEditorMetrics) -> some View {
        Button {
            viewModel.beginNotesEditor()
        } label: {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    if viewModel.notes.isEmpty {
                        Text("—")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(JChordTheme.muted)
                            .frame(height: metrics.controlHeight)
                    } else {
                        ForEach(viewModel.notes, id: \.self) { note in
                            noteChip(note, metrics: metrics)
                        }
                    }
                }
                .fixedSize(horizontal: true, vertical: false)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: metrics.controlHeight)
            .padding(.horizontal, 12)
            .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.string("pad_editor.input_notes.accessibility"))
        .accessibilityHint("Opens note editor")
    }

    private func actionBar(layout: JChordPadLayout, buttonHeight: CGFloat) -> some View {
        HStack(spacing: layout.gridSpacing) {
            Button(L10n.string("pad_editor.cancel")) {
                onCancel()
            }
            .buttonStyle(JChordEditorActionButtonStyle(primary: false))
            .frame(width: layout.cellSide, height: buttonHeight)

            Button(L10n.string("pad_editor.set")) {
                viewModel.save()
            }
            .buttonStyle(JChordEditorActionButtonStyle(primary: true))
            .frame(width: layout.cellSide, height: buttonHeight)
        }
        .frame(height: buttonHeight)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.heavy))
            .foregroundStyle(JChordTheme.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func rowLabel(_ text: String, width: CGFloat) -> some View {
        Text(text)
            .font(.caption.weight(.heavy))
            .foregroundStyle(JChordTheme.muted)
            .frame(width: width, alignment: .leading)
            .lineLimit(2)
            .minimumScaleFactor(0.8)
    }

    private func rootKeyboard(metrics: PadEditorMetrics) -> some View {
        PadEditorRootKeyboardView(
            metrics: metrics,
            selectedRoot: viewModel.root,
            onSelectRoot: { root in
                isLabelFieldFocused = false
                viewModel.selectRoot(root)
            }
        )
    }

    private func noteChip(_ note: UInt8, metrics: PadEditorMetrics) -> some View {
        Text(MidiNoteFormatter.format(note))
            .font(.caption.weight(.heavy))
            .foregroundStyle(.white.opacity(0.9))
            .padding(.horizontal, 12)
            .frame(height: metrics.controlHeight)
            .background(Color.white.opacity(0.07), in: Capsule())
    }
}

/// 回転後もポップアップ寸法が古い Geometry に引っ張られないよう再構築する。
func orientationLayoutID(isLandscape: Bool, width: CGFloat) -> String {
    "\(isLandscape ? "landscape" : "portrait")-\(Int(width.rounded()))"
}

