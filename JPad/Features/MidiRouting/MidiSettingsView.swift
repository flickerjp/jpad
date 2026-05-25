import SwiftUI
import UniformTypeIdentifiers

struct MidiSettingsView: View {
    @ObservedObject var midiService: MidiOutputService
    @Environment(\.dismiss) private var dismiss
    @StateObject private var proPurchaseService = ProPurchaseService()
    @AppStorage(ProPurchaseService.purchasedAppStorageKey) private var hasPresetSavePurchased = false
    @State private var proMembershipStatus = ProSubscriptionStatus.free
    @State private var isShowingHelpGuide = false
    @State private var isShowingProUpgrade = false
    @State private var isShowingLoadSoundImporter = false
    @State private var isShowingLoadSoundResult = false
    @State private var loadSoundResultMessage = ""
    @State private var isShowingOverwriteConfirm = false
    @State private var pendingImportURL: URL?

    var body: some View {
        GeometryReader { geometry in
            let layout = JChordPadLayout.make(
                size: geometry.size,
                safeArea: geometry.safeAreaInsets
            )
            let testPadWidth = layout.cellSide
            let isLandscape = geometry.size.width > geometry.size.height
            let contentWidth = geometry.size.width - 36
            let compactPanelMaxWidth = isLandscape ? contentWidth * 0.5 : nil

            ZStack(alignment: .topTrailing) {
                ScrollView {
                    MidiRoutingSettingsContent(
                        midiService: midiService,
                        testPadWidth: testPadWidth,
                        onHelpTapped: { isShowingHelpGuide = true },
                        onPreviewSoundLoadTapped: { isShowingLoadSoundImporter = true },
                        proMembershipStatus: proMembershipStatus,
                        onProPurchaseTap: proMembershipStatus.isActive ? nil : { isShowingProUpgrade = true },
                        compactPanelMaxWidth: compactPanelMaxWidth
                    )
                    .padding(.horizontal, 18)
                    .padding(.top, 52)
                    .padding(.bottom, isLandscape ? 8 : 12)
                }
                .safeAreaInset(edge: .bottom, spacing: 8) {
                    SettingsCreditFooter(text: AppBuildIdentity.settingsCreditMarqueeText)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(JChordTheme.popupPanel)
                }

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(JChordTheme.text)
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.08), in: Circle())
                }
                .buttonStyle(.plain)
                .padding(.top, 12)
                .padding(.trailing, 18)
                .accessibilityLabel(L10n.string("settings.close.accessibility"))
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .jChordPopupSheetBackground()
        .jChordSheetOuterBorder()
        .fullScreenCover(isPresented: $isShowingHelpGuide) {
            OnboardingView(midiService: midiService, style: .help) {
                isShowingHelpGuide = false
            }
        }
        .sheet(isPresented: $isShowingProUpgrade) {
            ProUpgradeSheet(
                purchaseService: proPurchaseService,
                onPurchased: { handleProPurchaseCompleted() },
                onRestored: { handleProRestoreCompleted(restored: $0) }
            )
            .presentationCornerRadius(18)
        }
        .fileImporter(
            isPresented: $isShowingLoadSoundImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                if midiService.hasCustomPreviewSound {
                    pendingImportURL = url
                    isShowingOverwriteConfirm = true
                } else {
                    importPreviewSound(from: url)
                }
            case .failure(let error):
                loadSoundResultMessage = error.localizedDescription
                isShowingLoadSoundResult = true
            }
        }
        .alert(
            L10n.string("settings.preview_sound.overwrite.title"),
            isPresented: $isShowingOverwriteConfirm,
            actions: {
                Button(L10n.string("alert.cancel"), role: .cancel) {
                    pendingImportURL = nil
                }
                Button(L10n.string("settings.preview_sound.overwrite.confirm"), role: .destructive) {
                    if let pendingImportURL {
                        importPreviewSound(from: pendingImportURL)
                    }
                    pendingImportURL = nil
                }
            },
            message: {
                Text(L10n.string("settings.preview_sound.overwrite.message"))
            }
        )
        .alert(
            L10n.string("settings.preview_sound.label"),
            isPresented: $isShowingLoadSoundResult,
            actions: {
                Button(L10n.string("alert.ok")) { }
            },
            message: {
                Text(loadSoundResultMessage)
            }
        )
        .onAppear {
            midiService.refreshEndpoints(reconfigureSession: false)
            Task { await refreshProMembershipStatus() }
        }
        .onDisappear {
            midiService.setTestNoteEnabled(false)
            midiService.warmUpPreviewEngineIfNeeded()
        }
    }

    private func importPreviewSound(from url: URL) {
        do {
            try midiService.importPreviewSound(from: url)
            loadSoundResultMessage = L10n.string("settings.preview_sound.import.success")
        } catch {
            loadSoundResultMessage = error.localizedDescription
        }
        isShowingLoadSoundResult = true
    }

    private func refreshProMembershipStatus() async {
        let status = await proPurchaseService.refreshSubscriptionStatus()
        proMembershipStatus = status
        hasPresetSavePurchased = status.isActive
    }

    private func handleProPurchaseCompleted() {
        Task {
            await proPurchaseService.refreshEntitlement()
            await refreshProMembershipStatus()
            isShowingProUpgrade = false
        }
    }

    private func handleProRestoreCompleted(restored: Bool) {
        Task {
            await proPurchaseService.refreshEntitlement()
            let status = await proPurchaseService.refreshSubscriptionStatus()
            proMembershipStatus = status
            hasPresetSavePurchased = status.isActive
            if restored, status.isActive {
                isShowingProUpgrade = false
            }
        }
    }
}

// MARK: - Settings credit footer

private struct SettingsCreditFooter: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(JChordTheme.muted)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.75)
            .frame(maxWidth: .infinity, alignment: .center)
            .accessibilityLabel(text)
    }
}
