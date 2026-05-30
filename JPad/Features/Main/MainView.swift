import SwiftUI
import UniformTypeIdentifiers

struct MainView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var viewModel: MainViewModel
    @StateObject private var proPurchaseService = ProPurchaseService()
    @AppStorage(PadVisualStyleSettings.storageKey) private var padVisualStyleRaw = PadVisualStyle.dark.rawValue
    @State private var performanceRipples: [PadPerformanceEffectEngine.RippleWave] = []
    @State private var performanceNeighborBlinks: [PadPerformanceEffectEngine.NeighborBlinkEffect] = []
    /// 押下中の広がり（2 拍目の半分まで押したら true）
    @State private var pressGesturePadID: Int?
    @State private var pressGestureOriginCol: Int?
    @State private var pressGestureOriginRow: Int?
    @State private var pressGesturePressTime: TimeInterval?
    @State private var pressGestureHoldFlashQualified = false
    @State private var pressGestureInitialRippleID: UUID?
    /// 絶対時刻（2001〜）だと epoch が巨大になり色計算が固まるため、セッション起点のみ使う
    @State private var performanceTimelineOrigin: TimeInterval?
    @State private var performanceTimelineGeneration = 0
    /// パッド押下／持続発音中の 2 分音符 FLASH（次に打つタイムライン時刻）
    @State private var holdRipplePadID: Int?
    @State private var holdRippleNextFireTime: TimeInterval?
    private let performanceAnimationConfig = PadVisualStyleSettings.performanceAnimation
    /// ラベル入力などでキーボードが出ても PAD グリッドの寸法を維持する
    @State private var frozenPadLayoutSize: CGSize?
    @State private var frozenPadSafeArea: EdgeInsets = .init()

    init(viewModel: MainViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let padLayoutSize = frozenPadLayoutSize ?? geometry.size
                let padLayoutSafeArea = frozenPadLayoutSize == nil
                    ? geometry.safeAreaInsets
                    : frozenPadSafeArea
                let layout = JChordPadLayout.make(
                    size: padLayoutSize,
                    safeArea: padLayoutSafeArea
                )
                let columns = Array(
                    repeating: GridItem(.fixed(layout.cellSide), spacing: layout.gridSpacing, alignment: .center),
                    count: layout.columnCount
                )

                mainContent(layout: layout, columns: columns)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, layout.horizontalPadding)
                    .safeAreaInset(edge: .top, spacing: 0) {
                        topBar(layout: layout)
                            .padding(.horizontal, layout.horizontalPadding)
                            .frame(maxWidth: .infinity)
                            .frame(height: layout.topBarHeight)
                    }
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        bottomButtons(layout: layout)
                            .padding(.horizontal, layout.horizontalPadding)
                            .frame(maxWidth: .infinity)
                            .frame(height: layout.noteOffHeight)
                    }
                    .onChange(of: viewModel.notesEditorViewModel != nil) { _, isEditorOpen in
                        if isEditorOpen {
                            frozenPadLayoutSize = geometry.size
                            frozenPadSafeArea = geometry.safeAreaInsets
                        } else {
                            frozenPadLayoutSize = nil
                        }
                    }
            }
            .background {
                Group {
                    if usesPerformanceMainChrome {
                        PerformancePadPalette.screenBackground
                    } else {
                        JPadChromeTheme.mainScreenBackground
                    }
                }
                .ignoresSafeArea()
            }
            .onAppear {
                syncPerformanceTimelineIfNeeded()
            }
            .onChange(of: padVisualStyleRaw) { _, _ in
                if usesPerformanceMainChrome {
                    resetPerformanceTimeline()
                } else {
                    performanceTimelineOrigin = nil
                }
            }
            .onChange(of: viewModel.isPadEditMode) { _, isEditing in
                if isEditing {
                    performanceTimelineOrigin = nil
                    clearHoldRippleSchedule()
                } else if usesPerformanceMainChrome {
                    resetPerformanceTimeline()
                }
            }
            .onChange(of: viewModel.isHoldEnabled) { _, isHoldEnabled in
                if !isHoldEnabled {
                    clearHoldRippleSchedule()
                }
            }
            .onChange(of: viewModel.playingPadID) { _, playingPadID in
                if playingPadID == nil {
                    if !pressGestureHoldFlashQualified {
                        cancelPressGestureInitialRipple()
                    }
                    clearHoldRippleSchedule()
                    pressGestureHoldFlashQualified = false
                    pressGesturePadID = nil
                    pressGestureOriginCol = nil
                    pressGestureOriginRow = nil
                    pressGesturePressTime = nil
                    pressGestureInitialRippleID = nil
                }
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active, usesPerformanceMainChrome else { return }
                resetPerformanceTimeline()
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $viewModel.isShowingSettings) {
                MidiSettingsView(midiService: viewModel.midiService)
                    .presentationCornerRadius(18)
            }
            .sheet(isPresented: $viewModel.isShowingPresetRename) {
                PresetRenameSheet(
                    name: $viewModel.presetRenameDraftName,
                    onSave: { viewModel.commitPresetRename() },
                    onCancel: { viewModel.cancelPresetRename() }
                )
            }
            .sheet(isPresented: $viewModel.isShowingPresetPicker) {
                presetPickerSheetContent
                    .presentationCornerRadius(18)
            }
            .navigationDestination(isPresented: $viewModel.isShowingPadEditor) {
                if let pad = viewModel.selectedPadForEditor {
                    PadEditorView(
                        pad: pad,
                        midiService: viewModel.midiService,
                        onSave: { viewModel.updatePad($0) },
                        onCancel: { viewModel.cancelPadLabelEditor() }
                    )
                }
            }
            .overlay {
                if viewModel.notesEditorViewModel != nil {
                    MainPadNotesEditorOverlay(viewModel: viewModel)
                }
            }
            .alert(L10n.string("alert.preset_load_error"), isPresented: $viewModel.isShowingPresetError, actions: {
                Button(L10n.string("alert.ok")) { }
            }, message: {
                Text(viewModel.presetErrorMessage)
            })
            .alert(viewModel.presetNoticeTitle, isPresented: $viewModel.isShowingPresetNotice, actions: {
                Button(L10n.string("alert.ok")) { }
            }, message: {
                Text(viewModel.presetNoticeMessage)
            })
            .task {
                proPurchaseService.startTransactionListener()
                viewModel.onAppear()
            }
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .active:
                    viewModel.onBecomeActive()
                case .inactive, .background:
                    viewModel.onResignActive()
                @unknown default:
                    break
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    /// プリセットピッカー上に購入・共有・取り込みを重ねる（メイン画面の sheet とは別スタック）。
    private var presetPickerSheetContent: some View {
        PresetPickerView(
            librarySlots: viewModel.librarySlots,
            jcstoreEntries: viewModel.jcstoreEntries,
            isLoadingJcstore: viewModel.isLoadingJcstore,
            activeSlotID: viewModel.activeSlotID,
            maxSlots: viewModel.entitlement.maxUserPresetSlots,
            isProPurchased: viewModel.hasPresetSavePurchased,
            canCreateNewSlot: viewModel.canCreateNewSlot,
            canDuplicateActive: viewModel.canDuplicateActiveSlot,
            canShareActive: viewModel.canShareActiveSlot,
            onSelectSlot: { viewModel.selectLibrarySlot($0) },
            onDeleteSlot: { viewModel.deleteLibrarySlot($0) },
            onImportJcstore: { viewModel.importJcstorePreset(catalogID: $0) },
            onRefreshJcstore: {
                Task { await viewModel.refreshJcstoreManifest() }
            },
            onNewBlankSlot: { viewModel.createBlankSlot() },
            onDuplicateSlot: { viewModel.duplicateActiveSlot() },
            onSlotLimitReached: { viewModel.presentSlotLimitNotice() },
            onRequirePro: { viewModel.presentProUpgrade() },
            onShareRequiresActiveSet: { viewModel.presentShareRequiresActiveSetNotice() },
            onShare: { viewModel.exportActiveSlotForShare() },
            onImport: { viewModel.beginSharedPresetImport() },
            rotationUseAllSlots: viewModel.rotationUseAllSlots,
            isSlotInRotation: viewModel.isSlotIncludedInRotation,
            onRotationAllToggle: { viewModel.setRotationUseAll($0) },
            onRotationSlotToggle: { viewModel.setSlotRotationIncluded($0, included: $1) },
            onMoveSlot: { viewModel.moveLibrarySlot(from: $0, to: $1) }
        )
        .onAppear {
            viewModel.consumePendingPresetImportIfNeeded()
        }
        .onChange(of: viewModel.hasPresetSavePurchased) { _, _ in
            viewModel.refreshLibrarySlots()
        }
        .sheet(isPresented: $viewModel.isShowingStoreReplacePicker) {
            StoreReplacePickerView(
                slots: viewModel.librarySlots,
                onSelect: { viewModel.completeStoreImport(replacingSlotID: $0) }
            )
        }
        .sheet(isPresented: $viewModel.isShowingProUpgrade) {
            ProUpgradeSheet(
                purchaseService: proPurchaseService,
                onPurchased: { viewModel.handleProPurchaseCompleted() },
                onRestored: { viewModel.handleProRestoreCompleted(restored: $0) }
            )
            .presentationCornerRadius(18)
        }
        .sheet(isPresented: $viewModel.isShowingShareSheet) {
            if let url = viewModel.shareExportURL {
                ShareSheet(url: url)
            }
        }
        .fileImporter(
            isPresented: Binding(
                get: { viewModel.isShowingDocumentImporter },
                set: { viewModel.isShowingDocumentImporter = $0 }
            ),
            allowedContentTypes: UTType.jchordPresetImportTypes,
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                viewModel.importSharedPreset(from: url)
            case .failure(let error):
                viewModel.presentImportPickerError(error)
            }
        }
        .alert(L10n.string("alert.preset_load_error"), isPresented: $viewModel.isShowingPresetError, actions: {
            Button(L10n.string("alert.ok")) { }
        }, message: {
            Text(viewModel.presetErrorMessage)
        })
    }

    private func mainContent(layout: JChordPadLayout, columns: [GridItem]) -> some View {
        GeometryReader { geometry in
            let spacers = layout.interSectionSpacerHeights(forAvailableHeight: geometry.size.height)

            VStack(spacing: 0) {
                fixedSpacer(height: spacers.headerToPads)

                padGrid(layout: layout, columns: columns)

                fixedSpacer(height: spacers.betweenSections)

                if layout.isLandscape {
                    landscapeMidiControls(layout: layout)
                } else {
                    portraitControlPanel(layout: layout, spacing: spacers.betweenSections)
                }

                fixedSpacer(height: spacers.betweenSections)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    private var padControlModeBinding: Binding<PresetPadControlMode> {
        Binding(
            get: { viewModel.padControlMode },
            set: { viewModel.updatePadControlMode($0) }
        )
    }

    private func portraitControlPanel(layout: JChordPadLayout, spacing: CGFloat) -> some View {
        VStack(spacing: spacing) {
            if viewModel.isPadEditMode {
                editPadControlPanel(layout: layout)
            } else {
                controlRows(layout: layout)
            }
        }
    }

    private func padGrid(layout: JChordPadLayout, columns: [GridItem]) -> some View {
        Group {
            // グリッド全体に .id(tick) を付けると PadView が毎フレーム再生成され、押下中に onDisappear → Note Off になる
            if usesPerformanceMainChrome {
                PerformancePadAnimationTimeline(origin: $performanceTimelineOrigin) { animationTime in
                    padGridContent(
                        layout: layout,
                        columns: columns,
                        animationTime: animationTime
                    )
                    .onChange(of: animationTime) { _, newTime in
                        pressGestureHoldFlashQualificationTick(
                            animationTime: newTime,
                            layout: layout
                        )
                        holdQuarterNoteRippleTick(animationTime: newTime, layout: layout)
                        prunePerformanceEffects(animationTime: newTime, layout: layout)
                    }
                }
                .id(performanceTimelineGeneration)
            } else {
                padGridContent(layout: layout, columns: columns, animationTime: nil)
            }
        }
        .frame(width: layout.gridWidth, height: layout.gridHeight)
    }

    private func padGridContent(
        layout: JChordPadLayout,
        columns: [GridItem],
        animationTime: TimeInterval?
    ) -> some View {
        let orderedPads = viewModel.displayOrder(isLandscape: layout.isLandscape)
        return LazyVGrid(columns: columns, spacing: layout.gridSpacing) {
            ForEach(orderedPads) { pad in
                let slot = orderedPads.firstIndex(where: { $0.id == pad.id }) ?? pad.index
                let grid = PadGridLayoutGeometry.gridCoordinate(
                    slot: slot,
                    columnCount: layout.columnCount
                )
                let idle = performanceIdleAppearance(
                    col: grid.col,
                    row: grid.row,
                    columnCount: layout.columnCount,
                    padIndex: pad.index,
                    isLandscape: layout.isLandscape,
                    animationTime: animationTime
                )
                let ripple = performanceRippleAppearance(
                    gridCol: grid.col,
                    gridRow: grid.row,
                    columnCount: layout.columnCount,
                    animationTime: animationTime
                )

                PadView(
                    pad: pad,
                    displayPad: viewModel.displayPad(for: pad),
                    visualStyle: padVisualStyleForPad,
                    isMidiReady: viewModel.canEditPads,
                    isEditMode: viewModel.isPadEditMode,
                    isSelected: viewModel.isPadEditMode && viewModel.selectedPadID == pad.id,
                    isPlaying: viewModel.canEditPads && viewModel.playingPadID == pad.id,
                    isHoldPulsing: !usesPerformanceMainChrome
                        && viewModel.isHoldEnabled
                        && viewModel.playingPadID == pad.id,
                    sideLength: layout.cellSide,
                    orbitColorPhase: idle.colorPhase,
                    orbitBrightness: idle.brightness,
                    performanceAnimationConfig: performanceAnimationConfig,
                    rippleAppearance: ripple,
                    cornerRadius: layout.padCornerRadius,
                    contentPadding: layout.padContentPadding,
                    onPressChanged: { isPressed in
                        viewModel.handlePadPressChange(isPressed, pad: pad)
                        if isPressed {
                            handlePerformancePadPressDown(
                                padID: pad.id,
                                originCol: grid.col,
                                originRow: grid.row,
                                layout: layout,
                                animationTime: animationTime
                            )
                        } else {
                            handlePerformancePadPressUp(
                                padID: pad.id,
                                originCol: grid.col,
                                originRow: grid.row,
                                animationTime: animationTime
                            )
                        }
                    },
                    onEditNotesTap: {
                        viewModel.openPadNotesEditor(pad)
                    }
                )
            }
        }
    }

    private func performanceIdleAppearance(
        col: Int,
        row: Int,
        columnCount: Int,
        padIndex: Int,
        isLandscape: Bool,
        animationTime: TimeInterval?
    ) -> PadPerformanceEffectEngine.IdleAppearance {
        if reduceMotion {
            return PadPerformanceEffectEngine.idleAppearance(
                col: col,
                row: row,
                columnCount: columnCount,
                padIndex: padIndex,
                isLandscape: isLandscape,
                config: performanceAnimationConfig,
                reduceMotion: true
            )
        }
        guard let animationTime else {
            return PadPerformanceEffectEngine.IdleAppearance(
                colorPhase: 0,
                brightness: performanceAnimationConfig.idle.baseBrightness
            )
        }
        return PadPerformanceEffectEngine.idleAppearance(
            col: col,
            row: row,
            columnCount: columnCount,
            padIndex: padIndex,
            isLandscape: isLandscape,
            config: performanceAnimationConfig,
            time: animationTime
        )
    }

    private func performanceRippleAppearance(
        gridCol: Int,
        gridRow: Int,
        columnCount: Int,
        animationTime: TimeInterval?
    ) -> PadPerformanceEffectEngine.RippleAppearance {
        guard usesPerformanceMainChrome, let animationTime else {
            return .none
        }
        let rowCount = PadGridLayoutGeometry.rowCount(columnCount: columnCount)
        return PadPerformanceEffectEngine.rippleAppearance(
            gridCol: gridCol,
            gridRow: gridRow,
            waves: performanceRipples,
            neighborBlinks: performanceNeighborBlinks,
            columnCount: columnCount,
            rowCount: rowCount,
            config: performanceAnimationConfig,
            time: animationTime
        )
    }

    private func performanceAnimationTime(referenceTime: TimeInterval) -> TimeInterval {
        guard let origin = performanceTimelineOrigin else { return 0 }
        return max(0, referenceTime - origin)
    }

    private func syncPerformanceTimelineIfNeeded() {
        guard usesPerformanceMainChrome else {
            performanceTimelineOrigin = nil
            return
        }
        if performanceTimelineOrigin == nil {
            resetPerformanceTimeline()
        }
    }

    private func resetPerformanceTimeline() {
        performanceTimelineOrigin = nil
        performanceTimelineGeneration += 1
        performanceRipples = []
        performanceNeighborBlinks = []
        clearHoldRippleSchedule()
        clearPressGestureTracking()
    }

    private func clearHoldRippleSchedule() {
        holdRipplePadID = nil
        holdRippleNextFireTime = nil
    }

    private func clearPressGestureTracking() {
        pressGesturePadID = nil
        pressGestureOriginCol = nil
        pressGestureOriginRow = nil
        pressGesturePressTime = nil
        pressGestureHoldFlashQualified = false
        pressGestureInitialRippleID = nil
    }

    private func handlePerformancePadPressDown(
        padID: Int,
        originCol: Int,
        originRow: Int,
        layout: JChordPadLayout,
        animationTime: TimeInterval?
    ) {
        guard usesPerformanceMainChrome, !reduceMotion else { return }

        let time = resolvedPerformanceTime(animationTime)
        pressGesturePadID = padID
        pressGestureOriginCol = originCol
        pressGestureOriginRow = originRow
        pressGesturePressTime = time
        pressGestureHoldFlashQualified = false

        if !viewModel.isHoldEnabled {
            triggerNeighborDoubleBlink(
                originCol: originCol,
                originRow: originRow,
                animationTime: animationTime
            )
        }

        pressGestureInitialRippleID = triggerPerformanceRipple(
            originCol: originCol,
            originRow: originRow,
            layout: layout,
            animationTime: animationTime,
            usesHoldLoopTiming: usesPerformanceMainChrome
        )

        if viewModel.isHoldEnabled {
            pressGestureHoldFlashQualified = true
            scheduleHoldLoopRepeat(
                padID: padID,
                originCol: originCol,
                originRow: originRow,
                layout: layout
            )
        }
    }

    private func handlePerformancePadPressUp(
        padID: Int,
        originCol: Int,
        originRow: Int,
        animationTime: TimeInterval?
    ) {
        guard usesPerformanceMainChrome, !reduceMotion else { return }

        guard pressGesturePadID == padID else { return }

        if !pressGestureHoldFlashQualified {
            cancelPressGestureInitialRipple()
            clearHoldRippleSchedule()
        }

        let sustainHoldLoop = viewModel.isHoldEnabled && viewModel.playingPadID == padID
        if sustainHoldLoop {
            pressGesturePadID = nil
            pressGestureOriginCol = nil
            pressGestureOriginRow = nil
            pressGesturePressTime = nil
            pressGestureInitialRippleID = nil
        } else {
            clearPressGestureTracking()
        }
    }

    /// 2 拍目の半分（`holdFlashQualificationBeats`）まで押し続いたら広がり継続を有効化。
    private func pressGestureHoldFlashQualificationTick(
        animationTime: TimeInterval,
        layout: JChordPadLayout
    ) {
        guard !reduceMotion,
              usesPerformanceMainChrome,
              !viewModel.isHoldEnabled,
              let padID = pressGesturePadID,
              let pressTime = pressGesturePressTime,
              !pressGestureHoldFlashQualified,
              viewModel.playingPadID == padID
        else { return }

        guard animationTime >= pressTime + performanceAnimationConfig.holdFlashQualificationInterval
        else { return }

        pressGestureHoldFlashQualified = true
        guard let originCol = pressGestureOriginCol,
              let originRow = pressGestureOriginRow
        else { return }

        scheduleHoldLoopRepeat(
            padID: padID,
            originCol: originCol,
            originRow: originRow,
            layout: layout
        )
    }

    private func cancelPressGestureInitialRipple() {
        guard let rippleID = pressGestureInitialRippleID else { return }
        performanceRipples.removeAll { $0.id == rippleID }
    }

    private func prunePerformanceEffects(
        animationTime: TimeInterval,
        layout: JChordPadLayout
    ) {
        guard usesPerformanceMainChrome else { return }
        let rowCount = PadGridLayoutGeometry.rowCount(columnCount: layout.columnCount)
        performanceRipples = PadPerformanceEffectEngine.pruneExpiredWaves(
            performanceRipples,
            columnCount: layout.columnCount,
            rowCount: rowCount,
            config: performanceAnimationConfig,
            time: animationTime
        )
        performanceNeighborBlinks = PadPerformanceEffectEngine.pruneExpiredNeighborBlinks(
            performanceNeighborBlinks,
            config: performanceAnimationConfig,
            time: animationTime
        )
    }

    private func triggerNeighborDoubleBlink(
        originCol: Int,
        originRow: Int,
        animationTime: TimeInterval?
    ) {
        let now = resolvedPerformanceTime(animationTime)
        performanceNeighborBlinks.append(
            PadPerformanceEffectEngine.NeighborBlinkEffect(
                originCol: originCol,
                originRow: originRow,
                startedAt: now
            )
        )
        let limit = performanceAnimationConfig.ripple.maxConcurrentWaves
        if performanceNeighborBlinks.count > limit {
            performanceNeighborBlinks = Array(performanceNeighborBlinks.suffix(limit))
        }
    }

    private func resolvedPerformanceTime(_ animationTime: TimeInterval?) -> TimeInterval {
        if let animationTime {
            return animationTime
        }
        return performanceAnimationTime(referenceTime: Date.timeIntervalSinceReferenceDate)
    }

    /// HOLD 広がり: 5 個先で前の波と重なる周期ごとに原点から新しい波。
    private func holdQuarterNoteRippleTick(
        animationTime: TimeInterval,
        layout: JChordPadLayout
    ) {
        guard !reduceMotion, usesPerformanceMainChrome else { return }

        guard let padID = activeHoldRipplePadID(),
              shouldContinueHoldRippleLoop(padID: padID),
              let origin = performanceGridOrigin(padID: padID, layout: layout)
        else {
            if activeHoldRipplePadID() == nil, pressGesturePadID == nil {
                clearHoldRippleSchedule()
            }
            return
        }

        if holdRipplePadID != padID {
            holdRipplePadID = padID
        }

        if holdRippleNextFireTime == nil {
            scheduleHoldLoopRepeat(
                padID: padID,
                originCol: origin.col,
                originRow: origin.row,
                layout: layout
            )
            return
        }

        guard let nextFire = holdRippleNextFireTime else { return }
        guard animationTime >= nextFire else { return }

        holdRippleNextFireTime = nextFire + performanceAnimationConfig.holdLoopRepeatInterval
        triggerPerformanceRipple(
            originCol: origin.col,
            originRow: origin.row,
            layout: layout,
            animationTime: nextFire,
            usesHoldLoopTiming: usesPerformanceMainChrome
        )
    }

    private func activeHoldRipplePadID() -> Int? {
        viewModel.playingPadID ?? pressGesturePadID
    }

    private func shouldContinueHoldRippleLoop(padID: Int) -> Bool {
        if viewModel.isHoldEnabled {
            return viewModel.playingPadID == padID || pressGesturePadID == padID
        }
        return pressGestureHoldFlashQualified
            && (viewModel.playingPadID == padID || pressGesturePadID == padID)
    }

    private var usesHoldLoopRippleTiming: Bool {
        viewModel.isHoldEnabled || pressGestureHoldFlashQualified
    }

    /// 次ループは「押下時刻＋最遠到達」で予約（認定時刻＋2 拍にしない）。
    private func scheduleHoldLoopRepeat(
        padID: Int,
        originCol: Int,
        originRow: Int,
        layout: JChordPadLayout
    ) {
        guard let pressTime = pressGesturePressTime else { return }

        holdRipplePadID = padID
        holdRippleNextFireTime = pressTime + performanceAnimationConfig.holdLoopRepeatInterval
    }

    private func performanceGridOrigin(
        padID: Int,
        layout: JChordPadLayout
    ) -> (col: Int, row: Int)? {
        let orderedPads = viewModel.displayOrder(isLandscape: layout.isLandscape)
        guard let slot = orderedPads.firstIndex(where: { $0.id == padID }) else { return nil }
        return PadGridLayoutGeometry.gridCoordinate(
            slot: slot,
            columnCount: layout.columnCount
        )
    }

    @discardableResult
    private func triggerPerformanceRipple(
        originCol: Int,
        originRow: Int,
        layout: JChordPadLayout,
        animationTime: TimeInterval? = nil,
        usesHoldLoopTiming: Bool = false
    ) -> UUID {
        let now: TimeInterval
        if let animationTime {
            now = animationTime
        } else {
            let referenceTime = Date.timeIntervalSinceReferenceDate
            now = performanceAnimationTime(referenceTime: referenceTime)
        }
        let wave = PadPerformanceEffectEngine.RippleWave(
            originCol: originCol,
            originRow: originRow,
            startedAt: now,
            usesHoldLoopTiming: usesHoldLoopTiming
        )
        var waves = performanceRipples
        waves.append(wave)
        let rowCount = PadGridLayoutGeometry.rowCount(columnCount: layout.columnCount)
        waves = PadPerformanceEffectEngine.pruneExpiredWaves(
            waves,
            columnCount: layout.columnCount,
            rowCount: rowCount,
            config: performanceAnimationConfig,
            time: now
        )
        performanceNeighborBlinks = PadPerformanceEffectEngine.pruneExpiredNeighborBlinks(
            performanceNeighborBlinks,
            config: performanceAnimationConfig,
            time: now
        )
        let limit = performanceAnimationConfig.ripple.maxConcurrentWaves
        if waves.count > limit {
            waves = Array(waves.suffix(limit))
        }
        performanceRipples = waves
        return wave.id
    }

    private var padVisualStyle: PadVisualStyle {
        PadVisualStyle(rawValue: padVisualStyleRaw) ?? PadVisualStyleSettings.defaultStyle
    }

    /// EDIT 中は常にダーク。通常時は設定の PAD STYLE に従う。
    private var padVisualStyleForPad: PadVisualStyle {
        viewModel.isPadEditMode ? .dark : padVisualStyle
    }

    private var usesPerformanceMainChrome: Bool {
        padVisualStyle == .performance && !viewModel.isPadEditMode
    }

    private func fixedSpacer(height: CGFloat) -> some View {
        Color.clear.frame(height: height)
    }

    private var midiOutputStatusDot: some View {
        let isActive = viewModel.hasActiveMidiOutput
        return Circle()
            .fill(isActive ? JChordTheme.midiOutputActiveIndicator : JChordTheme.midiOutputInactiveIndicator)
            .frame(width: 8, height: 8)
            .accessibilityLabel(
                isActive
                    ? L10n.string("main.midi_out.active.accessibility")
                    : L10n.string("main.midi_out.inactive.accessibility")
            )
    }

    private func topBar(layout: JChordPadLayout) -> some View {
        ZStack {
            Button {
                if viewModel.isPadEditMode {
                    viewModel.openPresetRename()
                } else {
                    viewModel.openPresetPicker()
                }
            } label: {
                HStack(spacing: 6) {
                    Text(viewModel.presetTopBarTitle)
                        .font(.system(size: layout.noteOffFontSize, weight: .heavy))
                        .foregroundStyle(JChordTheme.text)
                        .lineLimit(1)
                    if !viewModel.isPadEditMode {
                        Image(systemName: "chevron.down")
                            .font(.system(size: layout.noteOffFontSize * 0.55, weight: .bold))
                            .foregroundStyle(JChordTheme.muted)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.06), in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isPadEditMode && !viewModel.canEditPads)
            .accessibilityLabel(
                viewModel.isPadEditMode
                    ? L10n.string("preset.rename.accessibility")
                    : L10n.string("preset.switch.accessibility")
            )
            .padding(.horizontal, layout.isLandscape ? 120 : 100)

            HStack(spacing: 8) {
                JPadChromeDockButton(
                    title: viewModel.isPadEditMode ? L10n.string("main.done") : L10n.string("main.edit"),
                    style: viewModel.isPadEditMode ? .accentToggle : .outline,
                    isOn: viewModel.isPadEditMode,
                    size: .compact,
                    action: { viewModel.toggleEditMode() }
                )
                .disabled(!viewModel.canEditPads)
                .opacity(viewModel.canEditPads ? 1 : 0.35)

                Spacer(minLength: 0)

                HStack(spacing: 8) {
                    midiOutputStatusDot

                    Button {
                        viewModel.presentSettings()
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: layout.gearIconSize, weight: .bold))
                            .foregroundStyle(JChordTheme.text)
                            .frame(width: layout.topBarHeight, height: layout.topBarHeight)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func landscapeMidiControls(layout: JChordPadLayout) -> some View {
        VStack(spacing: layout.gridSpacing) {
            if viewModel.isPadEditMode {
                editPadControlPanel(layout: layout)
            } else {
                controlRows(layout: layout)
            }
        }
        .frame(width: layout.gridWidth)
    }

    @ViewBuilder
    private func controlRows(layout: JChordPadLayout) -> some View {
        switch viewModel.padControlMode {
        case .sliders:
            performanceControlRows(layout: layout)
        case .transpose:
            transposePresetSelectorRow(layout: layout)
        }
    }

    @ViewBuilder
    private func performanceControlRows(layout: JChordPadLayout) -> some View {
        let content = Group {
            midiSliderRow(
                title: L10n.string("main.velocity"),
                value: viewModel.velocity,
                range: 1 ... 127,
                onChange: { viewModel.updateVelocity($0) },
                layout: layout
            )
            midiSliderRow(
                title: L10n.string("main.expression"),
                value: viewModel.expression,
                range: 1 ... 127,
                onChange: { viewModel.updateExpression($0) },
                layout: layout
            )
        }

        if layout.isLandscape {
            HStack(spacing: layout.gridSpacing) { content }
        } else {
            VStack(spacing: layout.gridSpacing) { content }
        }
    }

    private func editPadControlPanel(layout: JChordPadLayout) -> some View {
        VStack(spacing: layout.gridSpacing) {
            padControlModePicker(layout: layout)

            if viewModel.padControlMode == .transpose {
                transposePresetSelectorRow(layout: layout)
                transposeValueEditorRow(layout: layout)
            }
        }
    }

    private func transposePresetSelectorRow(layout: JChordPadLayout) -> some View {
        HStack(spacing: layout.gridSpacing) {
            ForEach(0 ..< PresetControlSettings.shiftMemoryCount, id: \.self) { index in
                let preset = viewModel.transposePreset(at: index)
                Button {
                    viewModel.selectTransposePreset(index: index)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(L10n.string("main.key")) \(signedValue(preset.keyShift))")
                            .font(.system(size: max(10, layout.noteOffHeight * 0.22), weight: .heavy))
                        Text("\(L10n.string("main.oct")) \(signedValue(preset.octaveShift))")
                            .font(.system(size: max(10, layout.noteOffHeight * 0.18), weight: .bold))
                            .opacity(0.82)
                    }
                    .foregroundStyle(
                        viewModel.selectedTransposePresetIndex == index
                            ? JPadChromeTheme.buttonLabelFilled
                            : JChordTheme.text
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: layout.noteOffHeight)
                    .padding(.horizontal, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(
                                viewModel.selectedTransposePresetIndex == index
                                    ? AnyShapeStyle(JPadChromeTheme.accentGradient)
                                    : AnyShapeStyle(JPadChromeTheme.buttonIdleFill)
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(
                                viewModel.selectedTransposePresetIndex == index
                                    ? JPadChromeTheme.accentLight.opacity(0.75)
                                    : JPadChromeTheme.buttonIdleBorder,
                                lineWidth: 1
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: layout.gridWidth)
    }

    private func transposeValueEditorRow(layout: JChordPadLayout) -> some View {
        HStack(spacing: layout.gridSpacing) {
            transposeValueStepper(
                title: L10n.string("main.key"),
                value: viewModel.selectedKeyTranspose,
                range: PresetShiftMemory.keyShiftRange,
                onChange: viewModel.updateKeyTranspose,
                layout: layout
            )
            transposeValueStepper(
                title: L10n.string("main.oct"),
                value: viewModel.selectedOctaveTranspose,
                range: PresetShiftMemory.octaveShiftRange,
                onChange: viewModel.updateOctaveTranspose,
                layout: layout
            )
        }
        .frame(width: layout.gridWidth)
    }

    private func transposeValueStepper(
        title: String,
        value: Int,
        range: ClosedRange<Int>,
        onChange: @escaping (Int) -> Void,
        layout: JChordPadLayout
    ) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.caption.weight(.heavy))
                .foregroundStyle(JChordTheme.muted)
                .frame(width: 32, alignment: .leading)

            Button {
                onChange(max(range.lowerBound, value - 1))
            } label: {
                Text("-")
                    .font(.headline.weight(.heavy))
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
            .disabled(value <= range.lowerBound)
            .opacity(value <= range.lowerBound ? 0.35 : 1)

            Text(signedValue(value))
                .font(.headline.monospacedDigit().weight(.heavy))
                .foregroundStyle(JChordTheme.text)
                .frame(maxWidth: .infinity)

            Button {
                onChange(min(range.upperBound, value + 1))
            } label: {
                Text("+")
                    .font(.headline.weight(.heavy))
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
            .disabled(value >= range.upperBound)
            .opacity(value >= range.upperBound ? 0.35 : 1)
        }
        .frame(maxWidth: .infinity)
        .frame(height: layout.noteOffHeight)
        .padding(.horizontal, 10)
        .background(JPadChromeTheme.buttonIdleFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(JPadChromeTheme.buttonIdleBorder, lineWidth: 1)
        )
    }

    private func padControlModePicker(layout: JChordPadLayout) -> some View {
        JChordSegmentedControl(
            options: PresetPadControlMode.allCases,
            selection: padControlModeBinding,
            title: { mode in
                switch mode {
                case .sliders:
                    return L10n.string("main.controls.performance")
                case .transpose:
                    return L10n.string("main.controls.transpose")
                }
            }
        )
        .frame(width: layout.gridWidth)
    }

    private func signedValue(_ value: Int) -> String {
        value > 0 ? "+\(value)" : "\(value)"
    }

    private func midiSliderRow(
        title: String,
        value: Double,
        range: ClosedRange<Double> = 1 ... 127,
        onChange: @escaping (Double) -> Void,
        layout: JChordPadLayout
    ) -> some View {
        HStack(alignment: .center, spacing: layout.midiSliderLabelSpacing) {
            Text(title)
                .font(.system(size: layout.midiSliderLabelSize, weight: .semibold))
                .foregroundStyle(JPadChromeTheme.primaryLabel)
                .frame(width: layout.midiSliderLabelWidth, alignment: .leading)

            JChordMidiSlider(
                value: Binding(
                    get: { value },
                    set: { onChange($0) }
                ),
                range: range
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: layout.midiSliderRowHeight)
    }

    private func bottomButtons(layout: JChordPadLayout) -> some View {
        let side = layout.noteOffHeight
        let dockFontSize = JPadOrangeChromeStyle.metrics(for: .standard).fontSize

        return HStack(spacing: layout.gridSpacing) {
            JPadSetCycleChevronButton(
                systemImage: "chevron.left",
                isEnabled: viewModel.canNavigateRotationSlots,
                size: side,
                action: { viewModel.selectPreviousRotationSlot() }
            )
            .accessibilityLabel(L10n.string("main.set_previous.accessibility"))

            JPadChromeDockButton(
                title: L10n.string("main.reset"),
                style: .outline,
                fontSize: dockFontSize,
                width: layout.cellSide,
                height: layout.noteOffHeight,
                action: { viewModel.sendAllNotesOff() }
            )
            .accessibilityLabel(L10n.string("main.reset"))

            JPadChromeDockButton(
                title: L10n.string("main.hold"),
                style: .accentToggle,
                isOn: viewModel.isHoldEnabled,
                fontSize: dockFontSize,
                width: layout.cellSide,
                height: layout.noteOffHeight,
                action: { viewModel.toggleHold() }
            )
            .jChordGentlePulse(viewModel.isHoldEnabled)
            .accessibilityLabel(L10n.string("main.hold"))

            JPadSetCycleChevronButton(
                systemImage: "chevron.right",
                isEnabled: viewModel.canNavigateRotationSlots,
                size: side,
                action: { viewModel.selectNextRotationSlot() }
            )
            .accessibilityLabel(L10n.string("main.set_next.accessibility"))
        }
        .frame(height: layout.noteOffHeight)
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

private struct MainPadNotesEditorOverlay: View {
    @ObservedObject var viewModel: MainViewModel

    var body: some View {
        if let notesViewModel = viewModel.notesEditorViewModel {
            GeometryReader { geometry in
                let isLandscape = geometry.size.width > geometry.size.height
                let layout = JChordPadLayout.make(
                    size: geometry.size,
                    safeArea: geometry.safeAreaInsets
                )
                let metrics = PadEditorMetrics(
                    isLandscape: isLandscape,
                    padLayout: layout,
                    size: geometry.size,
                    safeArea: geometry.safeAreaInsets
                )

                PadEditorPopupOverlay {
                    PadEditorNotesEditorFactory.make(
                        viewModel: notesViewModel,
                        midiService: viewModel.midiService,
                        padLayout: layout,
                        metrics: metrics,
                        showsCancelButton: true,
                        onSet: { viewModel.commitPadNotesEditorAndReturn() },
                        onCancel: { viewModel.cancelPadNotesEditorAndReturn() }
                    )
                    .id(orientationLayoutID(isLandscape: isLandscape, width: metrics.notePopupWidth))
                }
            }
            .ignoresSafeArea()
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .transition(.opacity)
        }
    }
}
