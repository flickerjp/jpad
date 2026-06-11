import SwiftUI
import UIKit
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
    @State private var activeHardwarePadKeys: Set<String> = []
    @State private var interfaceOrientation: UIInterfaceOrientation = .unknown

    private static let hardwarePadKeys = ["1", "2", "3", "q", "w", "e", "a", "s", "d", "z", "x", "c"]

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
                let isPortraitUpsideDown = interfaceOrientation == .portraitUpsideDown

                mainContent(layout: layout, columns: columns)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, layout.horizontalPadding)
                    .background {
                        HardwareKeyboardPadInputView(isEnabled: isHardwarePadInputEnabled) { key, isPressed in
                            handleHardwarePadKeyChange(
                                key,
                                isPressed: isPressed,
                                layout: layout
                            )
                        }
                        .frame(width: 0, height: 0)
                    }
                    .onChange(of: viewModel.notesEditorViewModel != nil) { _, isEditorOpen in
                        if isEditorOpen {
                            frozenPadLayoutSize = geometry.size
                            frozenPadSafeArea = geometry.safeAreaInsets
                        } else {
                            frozenPadLayoutSize = nil
                        }
                    }
                    .onChange(of: layout.isLandscape) { _, isLandscape in
                        guard isLandscape, viewModel.isPadEditMode else { return }
                        viewModel.toggleEditMode()
                    }
                    .modifier(
                        MainScreenChromeModifier(
                            layout: layout,
                            topBar: { topBar(layout: layout) },
                            bottomButtons: { bottomButtons(layout: layout) }
                        )
                    )
                    .rotationEffect(.degrees(isPortraitUpsideDown ? 180 : 0))
                    .onChange(of: isHardwarePadInputEnabled) { _, isEnabled in
                        if !isEnabled {
                            clearHardwarePadKeysAndStopPlaybackIfNeeded()
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
                updateInterfaceOrientation()
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
                guard phase == .active else { return }
                updateInterfaceOrientation()
                guard usesPerformanceMainChrome else { return }
                resetPerformanceTimeline()
            }
            .toolbar(.hidden, for: .navigationBar)
            .fullScreenCover(isPresented: $viewModel.isShowingSettings) {
                MidiSettingsView(
                    midiService: viewModel.midiService,
                    onClockSourceChanged: { viewModel.setExternalClockEnabled($0) },
                    internalClockBpm: Binding(
                        get: { Int(viewModel.sequencerSettings.bpm.rounded()) },
                        set: { viewModel.updateSequencerBpm(Double($0)) }
                    )
                )
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
            .overlay {
                if viewModel.isShowingArpEditor {
                    ArpPatternEditorOverlay(viewModel: viewModel)
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
                UIDevice.current.beginGeneratingDeviceOrientationNotifications()
                updateInterfaceOrientation()
                proPurchaseService.startTransactionListener()
                viewModel.onAppear()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                updateInterfaceOrientation()
            }
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .active:
                    updateInterfaceOrientation()
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

    private func updateInterfaceOrientation() {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
            ?? UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first
        else {
            return
        }

        let sceneOrientation = windowScene.interfaceOrientation

        // iPhone は縦持ちのまま上下逆へインターフェースを回さないため、
        // 物理デバイスの向きを使って縦表示の上下逆を補完する。
        guard sceneOrientation.isPortrait else {
            interfaceOrientation = sceneOrientation
            return
        }

        switch UIDevice.current.orientation {
        case .portraitUpsideDown:
            interfaceOrientation = .portraitUpsideDown
        case .portrait:
            interfaceOrientation = .portrait
        default:
            // faceUp / faceDown / landscape など曖昧な向きは直前の判定を維持する。
            break
        }
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
            onAirDrop: { viewModel.exportActiveSlotForAirDrop() },
            onExport: { viewModel.exportActiveSlotForExport() },
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
        .fileExporter(
            isPresented: $viewModel.isShowingExportSheet,
            document: viewModel.shareExportDocument,
            contentType: .json,
            defaultFilename: viewModel.shareExportFileName
        ) { _ in
            viewModel.dismissExportSheet()
        }
        .sheet(
            isPresented: $viewModel.isShowingAirDropSheet,
            onDismiss: { viewModel.dismissAirDropSheet() }
        ) {
            if let url = viewModel.airDropExportURL {
                AirDropSheet(url: url)
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
            let controlTopSpacer: CGFloat = 10

            Group {
                if layout.isLandscape {
                    HStack(alignment: .top, spacing: 0) {
                        landscapeSetCycleChevron(
                            systemImage: "chevron.left",
                            layout: layout,
                            accessibilityKey: "main.set_previous.accessibility",
                            action: { viewModel.selectPreviousRotationSlot() }
                        )

                        Spacer(minLength: 0)

                        HStack(alignment: .top, spacing: layout.gridSpacing) {
                            padGrid(layout: layout, columns: columns)
                            landscapeControlPanel(layout: layout)
                        }

                        Spacer(minLength: 0)

                        landscapeSetCycleChevron(
                            systemImage: "chevron.right",
                            layout: layout,
                            accessibilityKey: "main.set_next.accessibility",
                            action: { viewModel.selectNextRotationSlot() }
                        )
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                } else {
                    let spacers = layout.interSectionSpacerHeights(forAvailableHeight: geometry.size.height)

                    portraitControlPanel(
                        layout: layout,
                        spacing: viewModel.isPadEditMode ? controlTopSpacer : spacers.betweenSections,
                        spacers: spacers,
                        columns: columns,
                        controlTopSpacer: controlTopSpacer
                    )
                }
            }
        }
    }

    private func portraitControlPanel(
        layout: JChordPadLayout,
        spacing: CGFloat,
        spacers: (headerToPads: CGFloat, betweenSections: CGFloat),
        columns: [GridItem],
        controlTopSpacer: CGFloat
    ) -> some View {
        VStack(spacing: 0) {
            fixedSpacer(height: spacers.headerToPads)

            padGrid(layout: layout, columns: columns)

            fixedSpacer(height: controlTopSpacer)

            if !viewModel.isPadEditMode {
                VStack(spacing: spacing) {
                    controlRows(layout: layout)
                }
            }

            fixedSpacer(height: spacers.betweenSections)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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

    private var isHardwarePadInputEnabled: Bool {
        !viewModel.isShowingSettings
            && !viewModel.isShowingPresetRename
            && !viewModel.isShowingPresetPicker
            && !viewModel.isShowingPadEditor
            && viewModel.notesEditorViewModel == nil
    }

    private func handleHardwarePadKeyChange(
        _ key: String,
        isPressed: Bool,
        layout: JChordPadLayout
    ) {
        guard let slot = Self.hardwarePadKeys.firstIndex(of: key) else { return }
        let orderedPads = viewModel.displayOrder(isLandscape: layout.isLandscape)
        guard slot < orderedPads.count else { return }

        if isPressed {
            guard activeHardwarePadKeys.insert(key).inserted else { return }
        } else {
            guard activeHardwarePadKeys.remove(key) != nil else { return }
        }

        let pad = orderedPads[slot]
        let grid = PadGridLayoutGeometry.gridCoordinate(
            slot: slot,
            columnCount: layout.columnCount
        )

        viewModel.handlePadPressChange(isPressed, pad: pad)
        if isPressed {
            handlePerformancePadPressDown(
                padID: pad.id,
                originCol: grid.col,
                originRow: grid.row,
                layout: layout,
                animationTime: nil
            )
        } else {
            handlePerformancePadPressUp(
                padID: pad.id,
                originCol: grid.col,
                originRow: grid.row,
                animationTime: nil
            )
        }
    }

    private func clearHardwarePadKeysAndStopPlaybackIfNeeded() {
        guard !activeHardwarePadKeys.isEmpty else { return }
        activeHardwarePadKeys.removeAll()
        viewModel.sendAllNotesOff()
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

    private func landscapeControlPanel(layout: JChordPadLayout) -> some View {
        VStack(spacing: 8) {
            Group {
                switch viewModel.padControlMode {
                case .sliders:
                    landscapeSliderPanel(layout: layout)
                case .transpose:
                    landscapeTransposePresetColumn(layout: layout)
                case .arp:
                    ArpLandscapePanel(viewModel: viewModel, layout: layout)
                case .seq:
                    SeqLandscapePanel(viewModel: viewModel, layout: layout)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            landscapeActionButtonsRow(layout: layout)
        }
        .frame(width: layout.landscapeControlPanelWidth, height: layout.gridHeight, alignment: .top)
    }

    /// 横表示の左右端に上下中央で置くセット切替 ‹ ›（回転なし）。
    private func landscapeSetCycleChevron(
        systemImage: String,
        layout: JChordPadLayout,
        accessibilityKey: String,
        action: @escaping () -> Void
    ) -> some View {
        JPadSetCycleChevronButton(
            systemImage: systemImage,
            isEnabled: viewModel.canNavigateRotationSlots,
            size: layout.landscapeDockWidth,
            action: action
        )
        .frame(maxHeight: .infinity, alignment: .center)
        .accessibilityLabel(L10n.string(accessibilityKey))
    }

    private func landscapeActionButtonsRow(layout: JChordPadLayout) -> some View {
        let spacing: CGFloat = 8
        let buttonWidth = max(24, floor((layout.landscapeControlPanelWidth - spacing) / 2))
        let buttonHeight = max(26, floor(landscapeActionButtonReserveHeight(layout: layout) * 0.82))
        let buttonFontSize = max(14, layout.noteOffFontSize - 2)

        return VStack(spacing: 6) {
            Rectangle()
                .fill(Color.white.opacity(0.16))
                .frame(height: 1)
                .frame(maxWidth: .infinity)

            HStack(spacing: spacing) {
                JPadChromeDockButton(
                    title: "R",
                    style: .outline,
                    fontSize: buttonFontSize,
                    width: buttonWidth,
                    height: buttonHeight,
                    action: { viewModel.sendAllNotesOff() }
                )
                .accessibilityLabel(L10n.string("main.reset"))

                JPadChromeDockButton(
                    title: "H",
                    style: .accentToggle,
                    isOn: viewModel.isHoldEnabled,
                    fontSize: buttonFontSize,
                    width: buttonWidth,
                    height: buttonHeight,
                    action: { viewModel.toggleHold() }
                )
                .jChordGentlePulse(viewModel.isHoldEnabled)
                .accessibilityLabel(L10n.string("main.hold"))
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func controlRows(layout: JChordPadLayout) -> some View {
        VStack(spacing: 10) {
            padControlModePicker(layout: layout)

            switch viewModel.padControlMode {
            case .sliders:
                performanceControlRows(layout: layout)
            case .transpose:
                VStack(spacing: 10) {
                    transposePresetSelectorRow(layout: layout)
                    transposeValueWheelRow(layout: layout)
                }
            case .arp:
                ArpControlRows(viewModel: viewModel, layout: layout)
            case .seq:
                SeqControlRows(viewModel: viewModel, layout: layout)
            }
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

    private func landscapeSliderPanel(layout: JChordPadLayout) -> some View {
        HStack(alignment: .top, spacing: 16) {
            landscapeSliderControl(
                title: "V",
                value: viewModel.velocity,
                range: 1 ... 127,
                onChange: { viewModel.updateVelocity($0) },
                layout: layout
            )
            landscapeSliderControl(
                title: "E",
                value: viewModel.expression,
                range: 1 ... 127,
                onChange: { viewModel.updateExpression($0) },
                layout: layout
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func landscapeSliderControl(
        title: String,
        value: Double,
        range: ClosedRange<Double>,
        onChange: @escaping (Double) -> Void,
        layout: JChordPadLayout
    ) -> some View {
        VStack(spacing: 8) {
            // 縦スライダー: 上方向で増加、下方向で減少。利用可能な高さいっぱいまで伸ばす。
            JChordMidiSlider(
                value: Binding(
                    get: { value },
                    set: { onChange($0) }
                ),
                range: range,
                isVertical: true
            )
            .frame(width: 34)
            .frame(maxHeight: .infinity)

            // ラベルはスライダーの下方に配置する。
            Text(title)
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(JPadChromeTheme.primaryLabel)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func landscapeTransposePresetColumn(layout: JChordPadLayout) -> some View {
        let buttonHeight = landscapeTransposeButtonHeightForLandscape(layout: layout)
        return VStack(spacing: layout.gridSpacing) {
            ForEach(Array((0 ..< PresetControlSettings.shiftMemoryCount).reversed()), id: \.self) { index in
                transposePresetButton(
                    preset: viewModel.transposePreset(at: index),
                    layout: layout,
                    selected: viewModel.selectedTransposePresetIndex == index,
                    onTap: { viewModel.selectTransposePreset(index: index, forEdit: false) },
                    fixedWidth: layout.landscapeControlPanelWidth,
                    fixedHeight: buttonHeight
                )
                .buttonStyle(.plain)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func landscapeTransposeButtonHeightForLandscape(layout: JChordPadLayout) -> CGFloat {
        let actionReserve = landscapeActionButtonReserveHeight(layout: layout)
        let available = layout.gridHeight - actionReserve - layout.gridSpacing * CGFloat(PresetControlSettings.shiftMemoryCount - 1) - 4
        let buttonHeight = floor(available / CGFloat(PresetControlSettings.shiftMemoryCount))
        return max(56, buttonHeight)
    }

    private func landscapeActionButtonReserveHeight(layout: JChordPadLayout) -> CGFloat {
        max(26, floor(layout.landscapeTransposeButtonHeight * 0.36))
    }

    private func transposePresetSelectorRow(layout: JChordPadLayout) -> some View {
        HStack(spacing: layout.gridSpacing) {
            ForEach(0 ..< PresetControlSettings.shiftMemoryCount, id: \.self) { index in
                transposePresetButton(
                    preset: viewModel.transposePreset(at: index),
                    layout: layout,
                    selected: viewModel.isPadEditMode
                        ? viewModel.editSelectedTransposePresetIndex == index
                        : viewModel.selectedTransposePresetIndex == index,
                    onTap: { viewModel.selectTransposePreset(index: index, forEdit: viewModel.isPadEditMode) },
                    fixedWidth: nil,
                    fixedHeight: nil
                )
                .buttonStyle(.plain)
            }
        }
        .frame(width: layout.gridWidth)
    }

    private func transposeValueWheelRow(layout: JChordPadLayout) -> some View {
        let slotWidth = floor((layout.gridWidth - (layout.gridSpacing * 3)) / 4)
        let groupSpacing = max(20, layout.gridSpacing + 6)

        return HStack(spacing: groupSpacing) {
            HStack(spacing: 10) {
                transposeValueWheelLabel(L10n.string("main.key"), width: slotWidth * 0.46, alignment: .trailing)
                JChordValueWheelPicker(
                    values: Array(PresetShiftMemory.keyShiftRange.reversed()),
                    value: Binding(
                        get: { viewModel.selectedKeyTranspose },
                        set: { viewModel.updateKeyTranspose($0) }
                    ),
                    width: slotWidth,
                    height: max(32, layout.noteOffHeight * 0.72),
                    displayText: { signedValue($0) }
                )
            }
            .frame(maxWidth: .infinity, alignment: .trailing)

            HStack(spacing: 10) {
                transposeValueWheelLabel(L10n.string("main.oct"), width: slotWidth * 0.46, alignment: .leading)
                JChordValueWheelPicker(
                    values: Array(PresetShiftMemory.octaveShiftRange.reversed()),
                    value: Binding(
                        get: { viewModel.selectedOctaveTranspose },
                        set: { viewModel.updateOctaveTranspose($0) }
                    ),
                    width: slotWidth,
                    height: max(32, layout.noteOffHeight * 0.72),
                    displayText: { signedValue($0) }
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: layout.gridWidth)
    }

    private func transposeValueWheelLabel(
        _ title: String,
        width: CGFloat,
        alignment: Alignment
    ) -> some View {
        Text(title)
            .font(.system(size: 14, weight: .heavy, design: .default))
            .foregroundStyle(JChordTheme.muted)
            .frame(width: width, alignment: alignment)
    }

    private func padControlModePicker(layout: JChordPadLayout) -> some View {
        HStack(spacing: 14) {
            padControlModeRadioButton(
                title: L10n.string("main.controls.slider"),
                isSelected: viewModel.padControlMode == .sliders,
                layout: layout
            ) {
                viewModel.updatePadControlMode(.sliders)
            }

            padControlModeRadioButton(
                title: L10n.string("main.controls.transpose"),
                isSelected: viewModel.padControlMode == .transpose,
                layout: layout
            ) {
                viewModel.updatePadControlMode(.transpose)
            }

            padControlModeRadioButton(
                title: L10n.string("main.controls.arp"),
                isSelected: viewModel.padControlMode == .arp,
                layout: layout
            ) {
                viewModel.updatePadControlMode(.arp)
            }

            padControlModeRadioButton(
                title: L10n.string("main.controls.seq"),
                isSelected: viewModel.padControlMode == .seq,
                layout: layout
            ) {
                viewModel.updatePadControlMode(.seq)
            }

            Spacer(minLength: 0)
        }
        .frame(width: layout.gridWidth)
    }

    private func signedValue(_ value: Int) -> String {
        value > 0 ? "+\(value)" : "\(value)"
    }

    private func transposePresetButton(
        preset: PresetShiftMemory,
        layout: JChordPadLayout,
        selected: Bool,
        onTap: @escaping () -> Void,
        fixedWidth: CGFloat?,
        fixedHeight: CGFloat?
    ) -> some View {
        let slotWidth = fixedWidth ?? floor((layout.gridWidth - (layout.gridSpacing * 3)) / 4)
        let buttonHeight = fixedWidth == nil
            ? (layout.isPadDevice ? max(40, floor(slotWidth * 2 / 3)) : max(40, floor(slotWidth * 3 / 4)))
            : (fixedHeight ?? max(40, floor(slotWidth * 0.74)))
        let isFixedLandscapeButton = fixedWidth != nil
        let labelFontSize = isFixedLandscapeButton
            ? layout.landscapeTransposeLabelFontSize
            : (layout.isPadDevice ? max(10, buttonHeight * 0.18 - 1) : max(11, buttonHeight * 0.22 - 2))
        let valueFontSize = isFixedLandscapeButton
            ? layout.landscapeTransposeValueFontSize
            : (layout.isPadDevice ? max(11, buttonHeight * 0.23 - 1) : max(12, buttonHeight * 0.28 - 2))
        let valueWidth = max(24, valueFontSize * 1.9)
        let labelWidth = max(28, labelFontSize * 2.4)
        let labelColor = selected
            ? JPadChromeTheme.buttonLabelFilled
            : Color.white.opacity(0.9)
        let selectedBackground = AnyShapeStyle(JPadChromeTheme.buttonIdleFill)
        let selectedBorder = JPadChromeTheme.buttonIdleBorder
        // パッドの角丸とバランスを取りつつ、縦長ボタンで丸くなりすぎないよう高さで頭打ち。
        let cornerRadius = min(layout.padCornerRadius, buttonHeight * 0.32)

        return Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text("KEY")
                        .font(.system(size: labelFontSize, weight: .regular, design: .default))
                        .frame(width: labelWidth, alignment: .trailing)
                    Text(signedValue(preset.keyShift))
                        .font(.system(size: valueFontSize, weight: .regular, design: .default))
                        .monospacedDigit()
                        .frame(width: valueWidth, alignment: .trailing)
                }
                HStack(spacing: 4) {
                    Text("OCT")
                        .font(.system(size: labelFontSize, weight: .regular, design: .default))
                        .frame(width: labelWidth, alignment: .trailing)
                    Text(signedValue(preset.octaveShift))
                        .font(.system(size: valueFontSize, weight: .regular, design: .default))
                        .monospacedDigit()
                        .frame(width: valueWidth, alignment: .trailing)
                }
            }
            .foregroundStyle(labelColor)
            .frame(maxWidth: .infinity, minHeight: buttonHeight, alignment: .center)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        selected
                            ? selectedBackground
                            : AnyShapeStyle(Color.clear)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        selected
                            ? selectedBorder
                            : Color.white.opacity(0.85),
                        lineWidth: 1.2
                    )
            )
        }
        .frame(width: fixedWidth)
            .accessibilityLabel("\(L10n.string("main.key")) \(signedValue(preset.keyShift)), \(L10n.string("main.oct")) \(signedValue(preset.octaveShift))")
    }

    private func padControlModeRadioButton(
        title: String,
        isSelected: Bool,
        layout: JChordPadLayout,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: max(14, layout.noteOffHeight * 0.18 + 2), weight: .semibold))
                Text(title)
                    .font(.system(size: max(15, layout.noteOffHeight * 0.18 + 2), weight: .heavy))
            }
            .foregroundStyle(isSelected ? JChordTheme.text : JChordTheme.muted)
            .padding(.horizontal, 2)
            .frame(height: max(28, layout.noteOffHeight * 0.45))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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

private struct MainScreenChromeModifier<TopBar: View, BottomButtons: View>: ViewModifier {
    let layout: JChordPadLayout
    @ViewBuilder let topBar: () -> TopBar
    @ViewBuilder let bottomButtons: () -> BottomButtons

    @ViewBuilder
    func body(content: Content) -> some View {
        if layout.isLandscape {
            content
        } else {
            content
                .safeAreaInset(edge: .top, spacing: 0) {
                    topBar()
                        .padding(.horizontal, layout.horizontalPadding)
                        .frame(maxWidth: .infinity)
                        .frame(height: layout.topBarHeight)
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    bottomButtons()
                        .padding(.horizontal, layout.horizontalPadding)
                        .frame(maxWidth: .infinity)
                        .frame(height: layout.noteOffHeight)
                }
        }
    }
}
