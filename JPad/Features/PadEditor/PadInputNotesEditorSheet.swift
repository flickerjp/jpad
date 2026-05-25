import SwiftUI

/// Input Notes 編集ポップアップ（パッド編集画面・EDIT モードのメイン画面で共有）。
struct PadInputNotesEditorSheet: View {
    @ObservedObject var viewModel: PadEditorViewModel
    @ObservedObject var midiService: MidiOutputService
    let padLayout: JChordPadLayout
    let metrics: PadEditorMetrics
    let showsCancelButton: Bool
    let onSet: () -> Void
    let onCancel: () -> Void

    private let baseSectionSpacing: CGFloat = 14
    private let extraSectionSpacing: CGFloat = 20

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.string("pad_editor.input_notes"))
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(JChordTheme.text)

            HStack(alignment: .top, spacing: 10) {
                ZStack(alignment: .topLeading) {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.clearNoteSelection()
                        }

                    if viewModel.editingNotes.isEmpty {
                        Text(L10n.string("pad_editor.empty_notes"))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(JChordTheme.muted)
                            .frame(height: metrics.controlHeight, alignment: .leading)
                    } else {
                        NoteChipFlowLayout(spacing: 8) {
                            ForEach(viewModel.editingNotes, id: \.self) { note in
                                editableNoteChip(note)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, minHeight: metrics.controlHeight, alignment: .topLeading)
                .fixedSize(horizontal: false, vertical: true)

                editorClearButton
            }

            previewNoteButton

            actionButtons
        }
        .padding(metrics.notePopupPadding)
        .frame(width: metrics.notePopupWidth)
        .fixedSize(horizontal: false, vertical: true)
        .jChordPopupPanelChrome(cornerRadius: 18)
        .task {
            midiService.startNoteCapture { [weak viewModel] batch in
                guard let viewModel else { return }
                viewModel.appendEditingNotes(batch)
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

    @ViewBuilder
    private var actionButtons: some View {
        if showsCancelButton {
            HStack(spacing: padLayout.gridSpacing) {
                Button(L10n.string("pad_editor.cancel")) {
                    onCancel()
                }
                .buttonStyle(JChordEditorActionButtonStyle(primary: false))
                .frame(width: padLayout.cellSide, height: metrics.actionButtonHeight)

                Button(L10n.string("pad_editor.set")) {
                    onSet()
                }
                .buttonStyle(JChordEditorActionButtonStyle(primary: true))
                .frame(width: padLayout.cellSide, height: metrics.actionButtonHeight)
            }
            .frame(height: metrics.actionButtonHeight)
            .frame(maxWidth: .infinity, alignment: .center)
        } else {
            Button(L10n.string("pad_editor.set")) {
                onSet()
            }
            .buttonStyle(JChordEditorActionButtonStyle(primary: true))
            .frame(width: padLayout.cellSide, height: metrics.actionButtonHeight)
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var previewNoteButton: some View {
        JChordTestNotePadButton(
            titleKey: "pad_editor.preview_note",
            appearance: .midiAccent,
            isMidiOutputActive: midiService.hasActiveMidiOutput,
            width: padLayout.cellSide,
            height: metrics.actionButtonHeight
        ) { isPressed in
            let pad = viewModel.draftPad(using: viewModel.editingNotes)
            if isPressed {
                midiService.sendPadOn(pad)
            } else {
                midiService.sendPadOff(pad)
            }
        }
        .accessibilityLabel(L10n.string("pad_editor.preview_note.accessibility"))
        .padding(.top, 6)
        .padding(.bottom, extraSectionSpacing)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func editableNoteChip(_ note: UInt8) -> some View {
        let isMarked = viewModel.isNoteMarkedForDeletion(note)

        return HStack(spacing: 8) {
            Button {
                viewModel.handleNoteChipTap(note)
            } label: {
                Text(MidiNoteFormatter.format(note))
                    .font(.caption.weight(.heavy))
            }
            .buttonStyle(.plain)

            if isMarked {
                Button {
                    viewModel.deleteEditingNote(note)
                } label: {
                    Text("×")
                        .font(.caption.weight(.black))
                        .frame(width: 22, height: 22)
                        .background(Color.white.opacity(0.08), in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .foregroundStyle(.white.opacity(0.9))
        .padding(.horizontal, 12)
        .frame(height: metrics.controlHeight)
        .background(
            isMarked ? Color.white.opacity(0.14) : Color.white.opacity(0.07),
            in: Capsule()
        )
        .overlay(
            Capsule()
                .strokeBorder(
                    isMarked ? Color.white.opacity(0.35) : Color.clear,
                    lineWidth: 1
                )
        )
    }

    private var editorClearButton: some View {
        Button {
            viewModel.performEditorClear()
        } label: {
            Text("×")
                .font(.system(size: 22, weight: .black))
                .frame(width: 28, height: metrics.controlHeight)
        }
        .buttonStyle(.plain)
        .tint(JChordTheme.midiAccentGlyph)
        .foregroundStyle(JChordTheme.midiAccentGlyph)
    }
}

struct NoteChipFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        layout(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var frames: [CGRect] = []

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: y + rowHeight), frames)
    }
}
