import SwiftUI

enum PadEditorNotesEditorFactory {
    @MainActor
    @ViewBuilder
    static func make(
        viewModel: PadEditorViewModel,
        midiService: MidiOutputService,
        padLayout: JChordPadLayout,
        metrics: PadEditorMetrics,
        showsCancelButton: Bool,
        onSet: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) -> some View {
        switch PadEditorUIVersion.current {
        case .v1:
            PadInputNotesEditorSheet(
                viewModel: viewModel,
                midiService: midiService,
                padLayout: padLayout,
                metrics: metrics,
                showsCancelButton: showsCancelButton,
                onSet: onSet,
                onCancel: onCancel
            )
        case .v11:
            PadKeyInputEditorSheetV11(
                viewModel: viewModel,
                midiService: midiService,
                padLayout: padLayout,
                metrics: metrics,
                showsCancelButton: showsCancelButton,
                onSet: onSet,
                onCancel: onCancel
            )
        }
    }
}
