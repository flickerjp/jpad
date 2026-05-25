import SwiftUI

private enum PresetPickerTab: Hashable {
    case mySets
    case store
}

struct PresetPickerView: View {
    let librarySlots: [UserPresetSlotEntry]
    let jcstoreEntries: [JcstoreCatalogEntry]
    let isLoadingJcstore: Bool
    let activeSlotID: String?
    let maxSlots: Int
    let isProPurchased: Bool
    let canCreateNewSlot: Bool
    let canDuplicateActive: Bool
    let canShareActive: Bool
    let onSelectSlot: (String) -> Void
    let onDeleteSlot: (String) -> Void
    let onImportJcstore: (String) -> Void
    let onRefreshJcstore: () -> Void
    let onNewBlankSlot: () -> Void
    let onDuplicateSlot: () -> Void
    let onSlotLimitReached: () -> Void
    let onRequirePro: () -> Void
    let onShareRequiresActiveSet: () -> Void
    let onShare: () -> Void
    let onImport: () -> Void
    let rotationUseAllSlots: Bool
    let isSlotInRotation: (String) -> Bool
    let onRotationAllToggle: (Bool) -> Void
    let onRotationSlotToggle: (String, Bool) -> Void
    let onMoveSlot: (Int, Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: PresetPickerTab = .mySets
    @State private var reorderDragSlotID: String?
    @State private var reorderDragStartY: CGFloat?
    @State private var rowFramesByID: [String: CGRect] = [:]
    @State private var bottomButtonLayout: JChordPadLayout?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                JChordSegmentedControl(
                    options: PresetPickerTab.allCases,
                    selection: $selectedTab,
                    title: tabTitle
                )
                .padding(.horizontal, 18)
                .padding(.top, 6)
                .padding(.bottom, 8)

                Group {
                    switch selectedTab {
                    case .mySets:
                        mySetsList
                    case .store:
                        storeList
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                presetFooterBar
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(JChordTheme.popupPanel)
            }
            .onGeometryChange(for: CGSize.self) { proxy in
                proxy.size
            } action: { size in
                bottomButtonLayout = JChordPadLayout.make(
                    size: size,
                    safeArea: .init()
                )
            }
            .onAppear {
                if bottomButtonLayout == nil {
                    bottomButtonLayout = Self.fallbackBottomButtonLayout()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if selectedTab == .mySets {
                        rotationAllToggle
                    }
                }
                .jChordToolbarNoGlassBackground()
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text(L10n.string("preset.picker.title"))
                            .font(.headline.weight(.semibold))
                        Text(slotCountLabel)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(JChordTheme.muted)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 4) {
                        if selectedTab == .mySets {
                            duplicateToolbarAction
                        }
                        closeToolbarAction
                    }
                }
                .jChordToolbarNoGlassBackground()
            }
        }
        .jChordPopupSheetBackground()
        .jChordSheetOuterBorder()
    }

    private var mySetsList: some View {
        List {
            if librarySlots.isEmpty {
                Text(L10n.string("preset.library.empty"))
                    .font(.caption)
                    .foregroundStyle(JChordTheme.muted)
                    .listRowBackground(JChordTheme.panel)
            } else {
                ForEach(Array(librarySlots.enumerated()), id: \.element.id) { index, slot in
                    MySetSlotRow(
                        slot: slot,
                        subtitle: mySetSubtitle(slot),
                        isSelected: slot.id == activeSlotID,
                        isInRotation: isSlotInRotation(slot.id),
                        isReordering: reorderDragSlotID == slot.id,
                        onRotationToggle: { included in
                            onRotationSlotToggle(slot.id, included)
                        },
                        onSelect: {
                            onSelectSlot(slot.id)
                            dismiss()
                        },
                        onReorderDragChanged: { startY in
                            reorderDragSlotID = slot.id
                            if reorderDragStartY == nil {
                                reorderDragStartY = startY
                            }
                        },
                        onReorderDragEnded: { location, startY in
                            finishReorderDrag(
                                slotID: slot.id,
                                dropLocation: location,
                                dragStartY: reorderDragStartY ?? startY
                            )
                        }
                    )
                    .background(rowFrameReader(slotID: slot.id))
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            onDeleteSlot(slot.id)
                        } label: {
                            Text(L10n.string("preset.library.delete"))
                        }
                    }
                }
            }

            addBlankSlotRow
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollDisabled(reorderDragSlotID != nil)
        .onPreferenceChange(SlotRowFramePreferenceKey.self) { rowFramesByID = $0 }
    }

    private func rowFrameReader(slotID: String) -> some View {
        GeometryReader { proxy in
            Color.clear
                .allowsHitTesting(false)
                .preference(
                    key: SlotRowFramePreferenceKey.self,
                    value: [slotID: proxy.frame(in: .global)]
                )
        }
    }

    private func finishReorderDrag(slotID: String, dropLocation: CGPoint, dragStartY: CGFloat) {
        defer {
            reorderDragSlotID = nil
            reorderDragStartY = nil
        }
        guard let fromIndex = librarySlots.firstIndex(where: { $0.id == slotID }) else { return }

        if let lastIndex = librarySlots.indices.last,
           let lastID = librarySlots.last?.id,
           let lastFrame = rowFramesByID[lastID],
           dropLocation.y > lastFrame.maxY
        {
            applyReorderMove(
                from: fromIndex,
                target: lastIndex,
                insertAfter: true
            )
            return
        }

        let otherRows = rowFramesByID.filter { $0.key != slotID }
        let targetID = otherRows.first(where: { _, frame in
            dropLocation.y >= frame.minY && dropLocation.y <= frame.maxY
        })?.key ?? otherRows.min(by: { lhs, rhs in
            abs(lhs.value.midY - dropLocation.y) < abs(rhs.value.midY - dropLocation.y)
        })?.key
        guard let targetID,
              let targetIndex = librarySlots.firstIndex(where: { $0.id == targetID }),
              let targetFrame = rowFramesByID[targetID]
        else { return }

        let dragDelta = dropLocation.y - dragStartY
        let insertAfter: Bool
        if dragDelta > 6 {
            insertAfter = true
        } else if dragDelta < -6 {
            insertAfter = false
        } else {
            insertAfter = dropLocation.y >= targetFrame.midY
        }

        applyReorderMove(from: fromIndex, target: targetIndex, insertAfter: insertAfter)
    }

    private func applyReorderMove(from fromIndex: Int, target targetIndex: Int, insertAfter: Bool) {
        let destination = reorderDestinationIndex(
            from: fromIndex,
            target: targetIndex,
            insertAfter: insertAfter
        )
        guard destination != fromIndex else { return }
        onMoveSlot(fromIndex, destination)
    }

    /// `move(fromOffsets:toOffset:)` 用。上方向は target の上、下方向は target の下へ挿入。
    private func reorderDestinationIndex(from fromIndex: Int, target targetIndex: Int, insertAfter: Bool) -> Int {
        if insertAfter {
            fromIndex <= targetIndex ? targetIndex + 1 : targetIndex + 1
        } else {
            fromIndex < targetIndex ? targetIndex - 1 : targetIndex
        }
    }

    private var addBlankSlotRow: some View {
        Button {
            if canCreateNewSlot {
                onNewBlankSlot()
                dismiss()
            } else {
                onSlotLimitReached()
            }
        } label: {
            HStack {
                Spacer(minLength: 0)
                Image(systemName: "plus")
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(canCreateNewSlot ? Color.white : JChordTheme.muted)
                Spacer(minLength: 0)
            }
            .frame(minHeight: presetRowMinHeight)
        }
        .buttonStyle(.plain)
        .listRowBackground(JChordTheme.popupPanel)
        .listRowSeparator(.hidden)
        .accessibilityLabel(L10n.string("preset.io.new_blank.accessibility"))
    }

    private var presetRowMinHeight: CGFloat { 52 }

    private var rotationAllToggle: some View {
        HStack(spacing: 6) {
            RotationCheckbox(isOn: rotationUseAllSlots)
            Text(L10n.string("preset.rotation.all"))
                .font(.caption.weight(.heavy))
                .foregroundStyle(JChordTheme.text)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .fixedSize(horizontal: true, vertical: false)
        .frame(minWidth: 64, alignment: .leading)
        .layoutPriority(1)
        .contentShape(Rectangle())
        .onTapGesture {
            onRotationAllToggle(!rotationUseAllSlots)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(L10n.string("preset.rotation.all.accessibility"))
        .accessibilityValue(
            rotationUseAllSlots
                ? L10n.string("preset.rotation.all.on")
                : L10n.string("preset.rotation.all.off")
        )
    }

    private var duplicateToolbarAction: some View {
        let isProLocked = !isProPurchased
        let isEnabled = activeSlotID != nil && (canDuplicateActive || isProLocked)
        let foregroundOpacity = canDuplicateActive
            ? 1.0
            : (isProLocked && activeSlotID != nil ? 0.55 : 0.35)
        return presetToolbarIconButton(
            systemName: "doc.on.doc",
            foregroundOpacity: foregroundOpacity,
            isEnabled: isEnabled,
            accessibilityLabel: L10n.string("preset.io.duplicate.accessibility")
        ) {
            guard activeSlotID != nil else { return }
            if !isProPurchased {
                onRequirePro()
            } else if canDuplicateActive {
                onDuplicateSlot()
            } else {
                onSlotLimitReached()
            }
        }
    }

    private var closeToolbarAction: some View {
        presetToolbarIconButton(
            systemName: "xmark",
            foregroundOpacity: 1,
            isEnabled: true,
            accessibilityLabel: L10n.string("preset.picker.close.accessibility")
        ) {
            dismiss()
        }
    }

    private func presetToolbarIconButton(
        systemName: String,
        foregroundOpacity: Double,
        isEnabled: Bool,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Image(systemName: systemName)
            .font(PresetPickerView.toolbarIconFont)
            .foregroundStyle(JChordTheme.muted.opacity(foregroundOpacity))
            .frame(width: PresetPickerView.toolbarIconSide, height: PresetPickerView.toolbarIconSide)
            .contentShape(Rectangle())
            .onTapGesture {
                guard isEnabled else { return }
                action()
            }
            .accessibilityElement(children: .ignore)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(accessibilityLabel)
            .opacity(isEnabled ? 1 : 0.35)
            .allowsHitTesting(isEnabled)
    }

    private static let toolbarIconSide: CGFloat = 44
    private static let toolbarIconFont = Font.body.weight(.semibold)

    private var storeList: some View {
        List {
            if isLoadingJcstore, jcstoreEntries.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowBackground(JChordTheme.panel)
            } else if jcstoreEntries.isEmpty {
                Text(L10n.string("jcstore.empty"))
                    .font(.caption)
                    .foregroundStyle(JChordTheme.muted)
                    .listRowBackground(JChordTheme.panel)
            } else {
                ForEach(jcstoreEntries) { entry in
                    Button {
                        onImportJcstore(entry.id)
                        dismiss()
                    } label: {
                        storeEntryRow(entry)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(JChordTheme.panel)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .refreshable {
            onRefreshJcstore()
        }
    }

    private var presetFooterBar: some View {
        Group {
            if PresetFeatureAvailability.isShareImportEnabled {
                let layout = bottomButtonLayout ?? Self.fallbackBottomButtonLayout()
                HStack(spacing: layout.gridSpacing) {
                    presetFooterActionButton(
                        layout: layout,
                        title: L10n.string("preset.io.share"),
                        isLocked: !isProPurchased,
                        primary: isProPurchased && canShareActive,
                        action: handleShareTap
                    )
                    .accessibilityLabel(L10n.string("preset.io.share"))

                    presetFooterActionButton(
                        layout: layout,
                        title: L10n.string("preset.io.import"),
                        isLocked: !isProPurchased,
                        primary: isProPurchased,
                        action: handleImportTap
                    )
                    .accessibilityLabel(L10n.string("preset.io.import"))

                    if !isProPurchased {
                        presetFooterPurchaseButton(layout: layout, action: onRequirePro)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: layout.noteOffHeight)
                .contentShape(Rectangle())
            }
        }
    }

    private func handleShareTap() {
        guard isProPurchased else {
            onRequirePro()
            return
        }
        guard canShareActive else {
            onShareRequiresActiveSet()
            return
        }
        onShare()
    }

    private func handleImportTap() {
        guard isProPurchased else {
            onRequirePro()
            return
        }
        onImport()
    }

    private static func fallbackBottomButtonLayout() -> JChordPadLayout {
        JChordPadLayout.make(
            size: CGSize(width: 390, height: 844),
            safeArea: .init()
        )
    }

    private func presetFooterActionButton(
        layout: JChordPadLayout,
        title: String,
        isLocked: Bool,
        primary: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(
            JChordNoteOffStyle(
                primary: primary,
                isLocked: isLocked,
                fontSize: layout.noteOffFontSize,
                height: layout.noteOffHeight
            )
        )
        .frame(width: layout.cellSide, height: layout.noteOffHeight)
    }

    private func presetFooterPurchaseButton(
        layout: JChordPadLayout,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(L10n.string("pro.picker.purchase"))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(
            JChordNoteOffStyle(
                isActive: true,
                fontSize: layout.noteOffFontSize,
                height: layout.noteOffHeight
            )
        )
        .frame(width: layout.cellSide, height: layout.noteOffHeight)
        .accessibilityLabel(L10n.string("pro.picker.purchase.accessibility"))
    }

    private func storeEntryRow(_ entry: JcstoreCatalogEntry) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(JChordTheme.text)
                if let published = entry.publishedDateText {
                    Text(published)
                        .font(.caption)
                        .foregroundStyle(JChordTheme.muted)
                }
                if let description = entry.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(JChordTheme.muted)
                        .multilineTextAlignment(.leading)
                }
            }
            Spacer(minLength: 8)
            Image(systemName: "arrow.down.circle")
                .font(.title3)
                .foregroundStyle(JChordTheme.accentOrangeMid)
        }
    }

    private var slotCountLabel: String {
        L10n.format("preset.library.slot_count", librarySlots.count, maxSlots)
    }

    private func tabTitle(_ tab: PresetPickerTab) -> String {
        switch tab {
        case .mySets:
            return L10n.string("preset.picker.tab.my_sets")
        case .store:
            return L10n.string("preset.picker.tab.store")
        }
    }

    private func mySetSubtitle(_ slot: UserPresetSlotEntry) -> String {
        let date = PresetDateFormatters.savedAtText(slot.savedAt)
        if slot.origin == .store {
            return "\(date) \(L10n.string("preset.library.origin_store_tag"))"
        }
        return date
    }

}

extension PresetPickerTab: CaseIterable {}

private extension ToolbarContent {
    @ToolbarContentBuilder
    func jChordToolbarNoGlassBackground() -> some ToolbarContent {
        if #available(iOS 26.0, *) {
            sharedBackgroundVisibility(.hidden)
        } else {
            self
        }
    }
}

private struct SlotRowFramePreferenceKey: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: [String: CGRect] = [:]

    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

// MARK: - MY SETS row（左スワイプ Delete は親の swipeActions）

private struct MySetSlotRow: View {
    let slot: UserPresetSlotEntry
    let subtitle: String
    let isSelected: Bool
    let isInRotation: Bool
    let isReordering: Bool
    let onRotationToggle: (Bool) -> Void
    let onSelect: () -> Void
    let onReorderDragChanged: (CGFloat) -> Void
    let onReorderDragEnded: (CGPoint, CGFloat) -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            dragHandle

            RotationCheckbox(isOn: isInRotation)
                .accessibilityElement(children: .ignore)
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel(L10n.string("preset.rotation.slot.accessibility"))
                .accessibilityValue(
                    isInRotation
                        ? L10n.string("preset.rotation.all.on")
                        : L10n.string("preset.rotation.all.off")
                )

            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(slot.setName)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(JChordTheme.text)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(JChordTheme.muted)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.bold))
                        .foregroundStyle(JChordTheme.accentOrangeMid)
                        .padding(.top, 2)
                }
            }
            .padding(.leading, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture(perform: onSelect)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(slot.setName)
            .accessibilityHint(L10n.string("preset.switch.accessibility"))
        }
        .overlay(alignment: .leading) {
            HStack(spacing: 0) {
                Color.clear
                    .frame(width: 36, height: 52)
                    .contentShape(Rectangle())
                    .highPriorityGesture(reorderDragGesture)
                Color.clear
                    .frame(width: 36, height: 52)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onRotationToggle(!isInRotation)
                    }
            }
        }
        .opacity(isReordering ? 0.65 : 1)
        .listRowBackground(JChordTheme.panel)
    }

    private var dragHandle: some View {
        Image(systemName: "line.3.horizontal")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Color.white.opacity(0.5))
            .frame(width: 28, height: 22, alignment: .leading)
            .accessibilityLabel(L10n.string("preset.library.reorder.accessibility"))
            .allowsHitTesting(false)
    }

    private var reorderDragGesture: some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .global)
            .onChanged { value in
                onReorderDragChanged(value.startLocation.y)
            }
            .onEnded { value in
                onReorderDragEnded(value.location, value.startLocation.y)
            }
    }
}
