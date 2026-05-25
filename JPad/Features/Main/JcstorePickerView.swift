import SwiftUI

struct JcstorePickerView: View {
    let entries: [JcstoreCatalogEntry]
    let isLoading: Bool
    let onSelect: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .listRowBackground(JChordTheme.panel)
                } else if entries.isEmpty {
                    Text(L10n.string("jcstore.empty"))
                        .font(.caption)
                        .foregroundStyle(JChordTheme.muted)
                        .listRowBackground(JChordTheme.panel)
                } else {
                    ForEach(entries) { entry in
                        Button {
                            onSelect(entry.id)
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.title)
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(JChordTheme.text)
                                }
                                Spacer()
                                Image(systemName: "arrow.down.circle")
                                    .foregroundStyle(JChordTheme.accentOrangeMid)
                            }
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(JChordTheme.panel)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .jChordScreenBackground()
            .navigationTitle(L10n.string("jcstore.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string("jcstore.close")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct StoreReplacePickerView: View {
    let slots: [UserPresetSlotEntry]
    let onSelect: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(slots) { slot in
                    Button {
                        onSelect(slot.id)
                        dismiss()
                    } label: {
                        Text(slot.setName)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(JChordTheme.text)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(JChordTheme.panel)
                }
            }
            .scrollContentBackground(.hidden)
            .jChordScreenBackground()
            .navigationTitle(L10n.string("jcstore.replace_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string("jcstore.close")) {
                        dismiss()
                    }
                }
            }
        }
    }
}
