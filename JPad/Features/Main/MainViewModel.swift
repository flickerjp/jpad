import Combine
import Foundation
import SwiftUI

@MainActor
final class MainViewModel: ObservableObject {
    @Published var preset: Preset
    @Published var isShowingSettings = false
    @Published var isShowingPresetPicker = false
    @Published var isShowingPresetRename = false
    @Published var presetRenameDraftName = ""
    @Published var isShowingPadEditor = false
    @Published private(set) var notesEditorViewModel: PadEditorViewModel?
    @Published private(set) var librarySlots: [UserPresetSlotEntry] = []
    @Published private(set) var activeSlotID: String?
    @Published var isShowingPresetError = false
    @Published var isShowingPresetNotice = false
    @Published var presetErrorMessage = ""
    @Published var presetNoticeTitle = ""
    @Published var presetNoticeMessage = ""
    @AppStorage(MidiPerformanceSettings.velocityKey) var velocity: Double = MidiPerformanceSettings.defaultValue
    @AppStorage(MidiPerformanceSettings.expressionKey) var expression: Double = MidiPerformanceSettings.defaultValue
    @Published var isEditMode = false
    @Published var selectedPadID: Int?
    @Published var isHoldEnabled = false
    @Published private(set) var playingPadID: Int?
    @Published var isShowingStoreReplacePicker = false
    @Published var isShowingShareSheet = false
    @Published var isShowingDocumentImporter = false
    @Published private(set) var jcstoreEntries: [JcstoreCatalogEntry] = []
    @Published private(set) var isLoadingJcstore = false
    @Published var shareExportURL: URL?
    @Published var isShowingProUpgrade = false
    @AppStorage(ProPurchaseService.purchasedAppStorageKey) var hasPresetSavePurchased = false
    @AppStorage(PresetRotationSettings.useAllSlotsKey) var rotationUseAllSlots = true
    @AppStorage(PresetRotationSettings.slotIDsKey) private var rotationSlotIDsStorage = ""

    private var holdLatchedPadID: Int?
    private var pendingTransposeSemitones: Int?
    private var isPendingTransposeArmed = false
    private var transposePreviewToken = UUID()
    private var pendingStoreCatalogID: String?
    private var pendingStorePreset: Preset?
    private var pendingPresetImportURL: URL?
    private var jcstoreManifest: JcstoreManifest?

    let midiService: MidiOutputService

    private let presetLoader: PresetLoader
    private var cancellables = Set<AnyCancellable>()

    init(
        presetLoader: PresetLoader = PresetLoader(),
        midiService: MidiOutputService = MidiOutputService()
    ) {
        self.presetLoader = presetLoader
        self.midiService = midiService
        self.preset = Preset.fallback

        bootstrapLibrary()

        midiService.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    var entitlement: Entitlement {
        Entitlement(isProPurchased: hasPresetSavePurchased)
    }

    var presetTopBarTitle: String {
        guard let activeSlotID,
              let entry = librarySlots.first(where: { $0.id == activeSlotID }) else {
            return L10n.string("preset.library.default_title")
        }
        return entry.setName.truncatedForTopBar(maxLength: 12)
    }

    var canEditPads: Bool {
        activeSlotID != nil
    }

    /// 保存済みスロットが無いときは EDIT UI を出さない（プレースホルダー用）。
    var isPadEditMode: Bool {
        isEditMode && canEditPads
    }

    var canCreateNewSlot: Bool {
        librarySlots.count < entitlement.maxUserPresetSlots
    }

    var canDuplicateActiveSlot: Bool {
        entitlement.canDuplicateSlots && activeSlotID != nil && canCreateNewSlot
    }

    var canShareActiveSlot: Bool {
        entitlement.canSharePresets && activeSlotID != nil
    }

    var storeOriginSlotCount: Int {
        librarySlots.filter { $0.origin == .store }.count
    }

    var rotationSlotsInOrder: [UserPresetSlotEntry] {
        if rotationUseAllSlots {
            return librarySlots
        }
        return librarySlots.filter { rotationSlotIDs.contains($0.id) }
    }

    var canNavigateRotationSlots: Bool {
        rotationSlotsInOrder.count > 1
    }

    var hasActiveMidiOutput: Bool {
        midiService.hasActiveMidiOutput
    }

    var padControlMode: PresetPadControlMode {
        preset.transposeSettings.padControlMode
    }

    var selectedTransposePresetIndex: Int? {
        preset.transposeSettings.selectedShiftMemoryIndex
    }

    var selectedTransposePreset: PresetShiftMemory {
        preset.transposeSettings.selectedMemory
    }

    func transposePreset(at index: Int) -> PresetShiftMemory {
        let memories = preset.transposeSettings.shiftMemories
        guard memories.indices.contains(index) else { return .neutral }
        return memories[index]
    }

    var selectedKeyTranspose: Int {
        selectedTransposePreset.keyShift
    }

    var selectedOctaveTranspose: Int {
        selectedTransposePreset.octaveShift
    }

    var selectedPadForEditor: PadDefinition? {
        guard let selectedPadID else { return nil }
        return preset.pads.first(where: { $0.id == selectedPadID })
    }

    func onAppear() {
        Task { await syncProEntitlementFromStore() }
        midiService.refreshEndpointsIfStale()
        midiService.preparePreviewAudioIfNeeded()
        Task { await midiService.primePreviewEngineForPadPlayback() }
        refreshLibrarySlots()
        Task { await refreshJcstoreManifest() }
    }

    func isSlotIncludedInRotation(_ slotID: String) -> Bool {
        if rotationUseAllSlots {
            return librarySlots.contains { $0.id == slotID }
        }
        return rotationSlotIDs.contains(slotID)
    }

    func setRotationUseAll(_ useAll: Bool) {
        rotationUseAllSlots = useAll
        rotationSlotIDs = []
    }

    func setSlotRotationIncluded(_ slotID: String, included: Bool) {
        guard librarySlots.contains(where: { $0.id == slotID }) else { return }

        if rotationUseAllSlots {
            if included { return }
            rotationUseAllSlots = false
            rotationSlotIDs = Set(librarySlots.map(\.id))
            rotationSlotIDs.remove(slotID)
            return
        }

        if included {
            rotationSlotIDs.insert(slotID)
        } else {
            rotationSlotIDs.remove(slotID)
        }

        if !librarySlots.isEmpty,
           rotationSlotIDs.count == librarySlots.count {
            rotationUseAllSlots = true
            rotationSlotIDs = []
        }
    }

    func selectPreviousRotationSlot() {
        selectAdjacentRotationSlot(forward: false)
    }

    func selectNextRotationSlot() {
        selectAdjacentRotationSlot(forward: true)
    }

    func moveLibrarySlot(from fromIndex: Int, to toIndex: Int) {
        do {
            try UserPresetLibrary.moveSlot(fromIndex: fromIndex, toIndex: toIndex)
            refreshLibrarySlots()
        } catch {
            presentPresetLibraryError(error)
        }
    }

    func selectLibrarySlot(_ id: String) {
        guard activeSlotID != id else { return }

        sendAllNotesOff()
        exitEditMode()
        persistActiveSlotIfNeeded()

        do {
            try UserPresetLibrary.setActiveSlot(id: id)
            let loaded = try UserPresetLibrary.loadPreset(slotID: id)
            applyLoadedPreset(loaded)
            activeSlotID = id
            refreshLibrarySlots()
        } catch {
            presentPresetLibraryError(error)
        }
    }

    func presentSlotLimitNotice() {
        presetNoticeTitle = L10n.string("preset.library.slot_limit_title")
        presetNoticeMessage = L10n.format(
            "preset.library.slot_limit_notice",
            entitlement.maxUserPresetSlots
        )
        isShowingPresetNotice = true
    }

    func createBlankSlot() {
        guard canCreateNewSlot else {
            presentSlotLimitNotice()
            return
        }
        do {
            sendAllNotesOff()
            exitEditMode()
            persistActiveSlotIfNeeded()
            let newID = try UserPresetLibrary.createBlankSlot(entitlement: entitlement)
            let loaded = try UserPresetLibrary.loadPreset(slotID: newID)
            applyLoadedPreset(loaded)
            activeSlotID = newID
            refreshLibrarySlots()
        } catch {
            presentPresetLibraryError(error)
        }
    }

    func renameLibrarySlot(_ id: String, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            var loaded = try UserPresetLibrary.loadPreset(slotID: id)
            loaded = loaded.withSetName(trimmed)
            try UserPresetLibrary.savePreset(loaded, slotID: id)
            if activeSlotID == id {
                preset = loaded
            }
            refreshLibrarySlots()
        } catch {
            presentPresetLibraryError(error)
        }
    }

    func presentProUpgrade() {
        isShowingProUpgrade = true
    }

    func presentShareRequiresActiveSetNotice() {
        presetNoticeTitle = L10n.string("preset.picker.title")
        presetNoticeMessage = L10n.string("alert.share_requires_active_set")
        isShowingPresetNotice = true
    }

    func syncProEntitlementFromStore() async {
        let isPro = await ProPurchaseService().refreshEntitlement()
        hasPresetSavePurchased = isPro
    }

    func handleProPurchaseCompleted() {
        Task {
            let isPro = await ProPurchaseService().refreshEntitlement()
            hasPresetSavePurchased = isPro
            refreshLibrarySlots()
            isShowingProUpgrade = false
            presetNoticeTitle = L10n.string("preset.picker.title")
            presetNoticeMessage = L10n.string("pro.upgrade.purchase_success")
            isShowingPresetNotice = true
        }
    }

    func handleProRestoreCompleted(restored: Bool) {
        Task {
            let isPro = await ProPurchaseService().refreshEntitlement()
            hasPresetSavePurchased = isPro
            refreshLibrarySlots()
            if restored, isPro {
                isShowingProUpgrade = false
                presetNoticeTitle = L10n.string("preset.picker.title")
                presetNoticeMessage = L10n.string("pro.upgrade.restore_success")
                isShowingPresetNotice = true
            }
        }
    }

    func duplicateActiveSlot() {
        guard entitlement.canDuplicateSlots else {
            presentProUpgrade()
            return
        }
        guard activeSlotID != nil else { return }
        guard canCreateNewSlot else {
            presentSlotLimitNotice()
            return
        }
        do {
            sendAllNotesOff()
            exitEditMode()
            persistActiveSlotIfNeeded()
            let newID = try UserPresetLibrary.duplicateActiveSlot(entitlement: entitlement)
            let loaded = try UserPresetLibrary.loadPreset(slotID: newID)
            applyLoadedPreset(loaded)
            activeSlotID = newID
            refreshLibrarySlots()
        } catch {
            presentPresetLibraryError(error)
        }
    }

    func deleteLibrarySlot(_ id: String) {
        do {
            sendAllNotesOff()
            exitEditMode()
            try UserPresetLibrary.deleteSlot(id: id)
            refreshLibrarySlots()
            if let activeID = activeSlotID,
               librarySlots.contains(where: { $0.id == activeID }) {
                let loaded = try UserPresetLibrary.loadPreset(slotID: activeID)
                applyLoadedPreset(loaded)
            } else {
                activeSlotID = librarySlots.first?.id
                if let activeID = activeSlotID {
                    let loaded = try UserPresetLibrary.loadPreset(slotID: activeID)
                    applyLoadedPreset(loaded)
                } else {
                    activeSlotID = nil
                    applyLoadedPreset(Preset.fallback)
                    syncEditAvailability()
                }
            }
        } catch {
            presentPresetLibraryError(error)
        }
    }

    func openPresetPicker() {
        isShowingPresetPicker = true
        Task { await refreshJcstoreManifest() }
    }

    func openPresetRename() {
        guard canEditPads, activeSlotID != nil else { return }
        presetRenameDraftName = preset.setName
        isShowingPresetRename = true
    }

    func commitPresetRename() {
        guard let activeSlotID else { return }
        renameLibrarySlot(activeSlotID, to: presetRenameDraftName)
        isShowingPresetRename = false
    }

    func cancelPresetRename() {
        isShowingPresetRename = false
    }

    func refreshJcstoreManifest() async {
        isLoadingJcstore = true
        defer { isLoadingJcstore = false }
        do {
            let manifest = try await JcstoreService.loadManifest()
            jcstoreManifest = manifest
            jcstoreEntries = manifest.presets
        } catch {
            jcstoreEntries = []
            presentPresetLibraryError(error)
        }
    }

    func importJcstorePreset(catalogID: String) {
        Task {
            do {
                let manifest: JcstoreManifest
                if let cached = jcstoreManifest {
                    manifest = cached
                } else {
                    manifest = try await JcstoreService.loadManifest()
                    jcstoreManifest = manifest
                }
                let loaded = try await JcstoreService.loadPreset(
                    catalogID: catalogID,
                    manifest: manifest,
                    presetLoader: presetLoader
                )

                if entitlement.maxConcurrentStoreImports != nil,
                   storeOriginSlotCount >= 1,
                   !canCreateNewSlot {
                    pendingStoreCatalogID = catalogID
                    pendingStorePreset = loaded
                    isShowingStoreReplacePicker = true
                    return
                }

                try finishStoreImport(preset: loaded, catalogID: catalogID, replaceSlotID: nil)
            } catch {
        presentPresetLibraryError(error)
    }
}
    }

    func completeStoreImport(replacingSlotID: String) {
        guard let catalogID = pendingStoreCatalogID,
              let loaded = pendingStorePreset else { return }
        pendingStoreCatalogID = nil
        pendingStorePreset = nil
        do {
            try finishStoreImport(preset: loaded, catalogID: catalogID, replaceSlotID: replacingSlotID)
        } catch {
            presentPresetLibraryError(error)
        }
    }

    func exportActiveSlotForShare() {
        guard entitlement.canSharePresets else {
            presentProUpgrade()
            return
        }
        guard activeSlotID != nil else {
            presentShareRequiresActiveSetNotice()
            return
        }

        do {
            try UserPresetLibrary.saveActiveSlot(preset: preset, entitlement: entitlement)
            refreshLibrarySlots()
            guard let activeSlotID,
                  let entry = librarySlots.first(where: { $0.id == activeSlotID })
            else {
                presentShareRequiresActiveSetNotice()
                return
            }
            shareExportURL = try PresetImportExportService.makeExportFileURL(
                slotName: entry.setName,
                origin: entry.origin,
                preset: preset
            )
            isShowingShareSheet = true
        } catch {
            presentPresetLibraryError(error)
        }
    }

    func beginSharedPresetImport() {
        guard entitlement.canSharePresets else {
            presentProUpgrade()
            return
        }
        isShowingDocumentImporter = true
    }

    func handleIncomingPresetFile(_ url: URL) {
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed { url.stopAccessingSecurityScopedResource() }
        }
        guard PresetImportExportService.isJChordPresetFile(url) else {
            presetErrorMessage = L10n.string("alert.import_unsupported_file")
            isShowingPresetError = true
            return
        }
        pendingPresetImportURL = url
        consumePendingPresetImportIfNeeded()
    }

    func consumePendingPresetImportIfNeeded() {
        guard OnboardingStore.hasCompleted else { return }
        guard let url = pendingPresetImportURL else { return }
        pendingPresetImportURL = nil
        importSharedPreset(from: url)
    }

    func presentImportPickerError(_ error: Error) {
        if (error as? CancellationError) != nil {
            return
        }
        presetErrorMessage = error.localizedDescription
        isShowingPresetError = true
    }

    func importSharedPreset(from url: URL) {
        guard entitlement.canSharePresets else {
            presentProUpgrade()
            return
        }

        do {
            let accessed = url.startAccessingSecurityScopedResource()
            defer {
                if accessed { url.stopAccessingSecurityScopedResource() }
            }
            let data = try PresetImportExportService.loadImportData(from: url)
            let imported = try PresetImportExportService.decodeSharedPreset(from: data)
            sendAllNotesOff()
            exitEditMode()
            let slotID = try UserPresetLibrary.importSharedUserPreset(imported, entitlement: entitlement)
            let loaded = try UserPresetLibrary.loadPreset(slotID: slotID)
            applyLoadedPreset(loaded)
            activeSlotID = slotID
            refreshLibrarySlots()
            presetNoticeTitle = L10n.string("preset.picker.title")
            presetNoticeMessage = L10n.string("alert.import_success")
            isShowingPresetNotice = true
        } catch {
            presentPresetLibraryError(error)
        }
    }

    func toggleEditMode() {
        guard canEditPads else {
            exitEditMode()
            return
        }
        isEditMode.toggle()
        if !isEditMode {
            exitEditMode()
        }
    }

    func openPadLabelEditor(_ pad: PadDefinition) {
        openPadNotesEditor(pad)
    }

    func openPadNotesEditor(_ pad: PadDefinition) {
        guard isEditMode, canEditPads else { return }
        isShowingPadEditor = false
        selectedPadID = pad.id
        let viewModel = PadEditorViewModel(pad: pad) { _ in }
        viewModel.beginNotesEditor()
        notesEditorViewModel = viewModel
    }

    func commitPadNotesEditorAndReturn() {
        guard let notesEditorViewModel else { return }
        let draft = notesEditorViewModel.draftPadFromEditing()
        notesEditorViewModel.commitNotesEditor()
        updatePad(draft)
    }

    func cancelPadNotesEditorAndReturn() {
        closeNotesEditor()
        returnToPadGridFromEditor()
    }

    func cancelPadLabelEditor() {
        returnToPadGridFromEditor()
    }

    func updatePad(_ pad: PadDefinition) {
        preset = preset.replacingPad(pad)
        persistActiveSlotIfNeeded()
        returnToPadGridFromEditor()
    }

    func displayPad(for pad: PadDefinition) -> PadDefinition {
        pad.shiftedDisplay(by: selectedKeyTranspose)
    }

    func selectTransposePreset(index: Int, previewInEditMode: Bool = false) {
        if !previewInEditMode, preset.transposeSettings.selectedShiftMemoryIndex == index {
            let updated = preset.transposeSettings.deselectingMemory()
            if hasSoundingPadNotes {
                applyControlSettingsPreservingSound(updated)
            } else {
                applyControlSettings(updated)
            }
            return
        }

        let updated = preset.transposeSettings.selectingMemory(index: index)
        if hasSoundingPadNotes {
            applyControlSettingsPreservingSound(updated)
        } else {
            applyControlSettings(updated)
        }

        guard previewInEditMode, !hasSoundingPadNotes else { return }
        previewTransposeSelectionIfPossible()
    }

    func updatePadControlMode(_ mode: PresetPadControlMode) {
        let updated = preset.transposeSettings.selectingPadControlMode(mode)
        applyControlSettings(updated)
    }

    func updateKeyTranspose(_ newValue: Int) {
        let updated = preset.transposeSettings.updatingSelectedMemory {
            PresetShiftMemory(keyShift: newValue, octaveShift: $0.octaveShift)
        }
        applyControlSettings(updated)
    }

    func updateOctaveTranspose(_ newValue: Int) {
        let updated = preset.transposeSettings.updatingSelectedMemory {
            PresetShiftMemory(keyShift: $0.keyShift, octaveShift: newValue)
        }
        applyControlSettings(updated)
    }

    func closeNotesEditor() {
        notesEditorViewModel = nil
        midiService.stopNoteCapture()
    }

    func handlePadPressChange(_ isPressed: Bool, pad: PadDefinition) {
        guard canEditPads else { return }

        if isPressed {
            handlePadPressDown(pad)
        } else {
            handlePadPressUp(pad)
        }
    }

    func sendAllNotesOff() {
        isHoldEnabled = false
        playingPadID = nil
        holdLatchedPadID = nil
        markPendingTransposeReadyIfNeeded()
        midiService.sendAllNotesOff()
        midiService.preparePreviewAudioIfNeeded()
    }

    func presentSettings() {
        guard !isShowingSettings else { return }

        // Settings presentation is an audio-state boundary. Clear the internal
        // synth and give the render thread one short settle window before the
        // sheet transition starts.
        sendAllNotesOff()
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            self?.isShowingSettings = true
        }
    }

    func updateVelocity(_ newVelocity: Double) {
        velocity = newVelocity
        midiService.updateVelocity(UInt8(clamping: Int(newVelocity.rounded())))
    }

    func updateExpression(_ newExpression: Double) {
        expression = newExpression
        midiService.updateExpression(UInt8(clamping: Int(newExpression.rounded())))
    }

    func onBecomeActive() {
        midiService.refreshEndpointsIfStale()
        midiService.preparePreviewAudioAfterReturningToForeground()
    }

    func onResignActive() {
        midiService.stopNoteCapture()
        midiService.handleAppResignActive()
        persistActiveSlotIfNeeded()
    }

    func displayOrder(isLandscape: Bool) -> [PadDefinition] {
        let orderedIndices: [Int] = isLandscape
            ? [1, 3, 5, 7, 9, 11, 0, 2, 4, 6, 8, 10]
            : [9, 10, 11, 6, 7, 8, 3, 4, 5, 0, 1, 2]

        let padsByIndex = Dictionary(uniqueKeysWithValues: preset.pads.map { ($0.index, $0) })
        return orderedIndices.compactMap { padsByIndex[$0] }
    }

    // MARK: - Private

    private func bootstrapLibrary() {
        do {
            let activeID = try UserPresetLibrary.ensureInitialized(
                entitlement: entitlement,
                presetLoader: presetLoader
            )
            activeSlotID = activeID
            refreshLibrarySlots()
            if let activeID {
                let loaded = try UserPresetLibrary.loadPreset(slotID: activeID)
                applyLoadedPreset(loaded)
            } else {
                activeSlotID = nil
                applyLoadedPreset(Preset.fallback)
                syncEditAvailability()
            }
        } catch {
            presentPresetLibraryError(error)
            activeSlotID = nil
            applyLoadedPreset(Preset.fallback)
            syncEditAvailability()
        }
    }

    func refreshLibrarySlots() {
        librarySlots = (try? UserPresetLibrary.slotEntries()) ?? []
        activeSlotID = try? UserPresetLibrary.activeSlotID()
        pruneRotationSlotIDs()
        syncEditAvailability()
    }

    private var rotationSlotIDs: Set<String> {
        get { PresetRotationSettings.loadSlotIDs(from: rotationSlotIDsStorage) }
        set { rotationSlotIDsStorage = PresetRotationSettings.saveSlotIDs(newValue) }
    }

    private func pruneRotationSlotIDs() {
        let valid = Set(librarySlots.map(\.id))
        let pruned = rotationSlotIDs.intersection(valid)
        if pruned != rotationSlotIDs {
            rotationSlotIDs = pruned
        }
    }

    private func selectAdjacentRotationSlot(forward: Bool) {
        let slots = rotationSlotsInOrder
        guard !slots.isEmpty else { return }

        if slots.count == 1 {
            if activeSlotID != slots[0].id {
                selectLibrarySlot(slots[0].id)
            }
            return
        }

        let currentIndex: Int
        if let activeSlotID,
           let index = slots.firstIndex(where: { $0.id == activeSlotID }) {
            currentIndex = index
        } else {
            currentIndex = forward ? -1 : 0
        }

        let nextIndex = forward
            ? (currentIndex + 1) % slots.count
            : (currentIndex - 1 + slots.count) % slots.count
        selectLibrarySlot(slots[nextIndex].id)
    }

    private func syncEditAvailability() {
        guard !canEditPads else { return }
        exitEditMode()
    }

    private func finishStoreImport(preset: Preset, catalogID: String, replaceSlotID: String?) throws {
        sendAllNotesOff()
        exitEditMode()
        persistActiveSlotIfNeeded()

        let slotID = try UserPresetLibrary.importStorePreset(
            preset,
            catalogID: catalogID,
            replaceSlotID: replaceSlotID,
            entitlement: entitlement
        )
        let loaded = try UserPresetLibrary.loadPreset(slotID: slotID)
        applyLoadedPreset(loaded)
        activeSlotID = slotID
        refreshLibrarySlots()
    }

    private func applyLoadedPreset(_ loadedPreset: Preset) {
        preset = loadedPreset
        let performanceVelocity = UInt8(clamping: Int(velocity.rounded()))
        let performanceExpression = UInt8(clamping: Int(expression.rounded()))
        midiService.configure(
            outputChannel: loadedPreset.midiChannel,
            velocity: performanceVelocity,
            expression: performanceExpression
        )
        midiService.updatePadTranspose(semitones: loadedPreset.transposeSettings.selectedMemory.totalSemitones)
    }

    private var hasSoundingPadNotes: Bool {
        playingPadID != nil
    }

    private func applyControlSettings(_ settings: PresetControlSettings) {
        guard settings != preset.transposeSettings else { return }
        clearPendingTranspose()
        sendAllNotesOffWithoutPendingArm()
        preset = preset.replacingControlSettings(settings)
        midiService.updatePadTranspose(semitones: settings.selectedMemory.totalSemitones)
        persistActiveSlotIfNeeded()
    }

    private func applyControlSettingsPreservingSound(_ settings: PresetControlSettings) {
        guard settings != preset.transposeSettings else { return }
        pendingTransposeSemitones = settings.selectedMemory.totalSemitones
        isPendingTransposeArmed = false
        preset = preset.replacingControlSettings(settings)
        persistActiveSlotIfNeeded()
    }

    private func clearPendingTranspose() {
        pendingTransposeSemitones = nil
        isPendingTransposeArmed = false
    }

    private func markPendingTransposeReadyIfNeeded() {
        guard pendingTransposeSemitones != nil else { return }
        isPendingTransposeArmed = true
    }

    private func applyPendingTransposeIfArmed() {
        guard isPendingTransposeArmed, let semitones = pendingTransposeSemitones else { return }
        clearPendingTranspose()
        midiService.updatePadTranspose(semitones: semitones)
    }

    private func sendAllNotesOffWithoutPendingArm() {
        isHoldEnabled = false
        playingPadID = nil
        holdLatchedPadID = nil
        midiService.sendAllNotesOff()
        midiService.preparePreviewAudioIfNeeded()
    }

    private func persistActiveSlotIfNeeded() {
        guard canEditPads else { return }

        do {
            try UserPresetLibrary.saveActiveSlot(preset: preset, entitlement: entitlement)
            refreshLibrarySlots()
        } catch {
            presentPresetLibraryError(error)
        }
    }

    private func presentPresetLibraryError(_ error: Error) {
        if case UserPresetLibraryError.slotLimitReached(let limit) = error {
            presetNoticeTitle = L10n.string("preset.library.slot_limit_title")
            presetNoticeMessage = L10n.format("preset.library.slot_limit_notice", limit)
            isShowingPresetNotice = true
            return
        }
        if error is PresetShareError {
            presetNoticeTitle = L10n.string("preset.io.share")
            presetNoticeMessage = error.localizedDescription
            isShowingPresetNotice = true
            return
        }
        presetErrorMessage = error.localizedDescription
        isShowingPresetError = true
    }

    private func returnToPadGridFromEditor() {
        selectedPadID = nil
        isShowingPadEditor = false
        closeNotesEditor()
    }

    private func exitEditMode() {
        isEditMode = false
        returnToPadGridFromEditor()
    }

    private func handlePadPressDown(_ pad: PadDefinition) {
        applyPendingTransposeIfArmed()

        if isHoldEnabled {
            if holdLatchedPadID == pad.id {
                releasePlayingPad(pad)
                holdLatchedPadID = nil
                return
            }

            holdLatchedPadID = nil

            if playingPadID == pad.id {
                return
            }

            if let previousID = playingPadID,
               previousID != pad.id,
               let previousPad = preset.pads.first(where: { $0.id == previousID }) {
                markPendingTransposeReadyIfNeeded()
                applyPendingTransposeIfArmed()
                midiService.transitionPad(from: previousPad, to: pad)
            } else {
                midiService.sendPadOn(pad)
            }
            playingPadID = pad.id
            return
        }

        playingPadID = pad.id
        midiService.sendPadOn(pad)
    }

    private func handlePadPressUp(_ pad: PadDefinition) {
        if isHoldEnabled {
            if playingPadID == pad.id {
                holdLatchedPadID = pad.id
            }
            return
        }

        playingPadID = nil
        midiService.sendPadOff(pad)
        markPendingTransposeReadyIfNeeded()
    }

    private func releasePlayingPad(_ pad: PadDefinition) {
        playingPadID = nil
        holdLatchedPadID = nil
        midiService.sendPadOff(pad)
        markPendingTransposeReadyIfNeeded()
    }

    private func previewTransposeSelectionIfPossible() {
        guard isPadEditMode else { return }

        let previewPad = selectedPadForEditor
            ?? playingPadID.flatMap { playingID in preset.pads.first(where: { $0.id == playingID }) }
            ?? preset.pads.first(where: { !$0.chordNotes.isEmpty || !$0.bassNotes.isEmpty })

        guard let previewPad else { return }

        let token = UUID()
        transposePreviewToken = token
        playingPadID = previewPad.id
        midiService.sendPadOn(previewPad)

        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(450))
            guard let self,
                  self.transposePreviewToken == token,
                  self.playingPadID == previewPad.id,
                  !self.isHoldEnabled else { return }
            self.playingPadID = nil
            self.midiService.sendPadOff(previewPad)
        }
    }

    func toggleHold() {
        if isHoldEnabled {
            isHoldEnabled = false
            playingPadID = nil
            holdLatchedPadID = nil
            markPendingTransposeReadyIfNeeded()
            midiService.sendAllNotesOff()
            return
        }
        holdLatchedPadID = nil
        isHoldEnabled = true
    }
}
