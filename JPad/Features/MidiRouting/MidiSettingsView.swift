import SwiftUI

struct MidiSettingsView: View {
    @ObservedObject var midiService: MidiOutputService
    @Environment(\.dismiss) private var dismiss
    @StateObject private var proPurchaseService = ProPurchaseService()
    @AppStorage(ProPurchaseService.purchasedAppStorageKey) private var hasPresetSavePurchased = false
    @State private var proMembershipStatus = ProSubscriptionStatus.free
    @State private var isShowingHelpGuide = false
    @State private var isShowingProUpgrade = false

    var body: some View {
        GeometryReader { geometry in
            let layout = JChordPadLayout.make(
                size: geometry.size,
                safeArea: geometry.safeAreaInsets
            )
            let testPadWidth = layout.cellSide
            let isLandscape = geometry.size.width > geometry.size.height
            let outerHorizontalPadding: CGFloat = 24
            let contentWidth = geometry.size.width - (outerHorizontalPadding * 2)
            let compactPanelMaxWidth = isLandscape ? contentWidth * 0.5 : nil

            ZStack(alignment: .topTrailing) {
                ScrollView {
                    MidiRoutingSettingsContent(
                        midiService: midiService,
                        testPadWidth: testPadWidth,
                        onHelpTapped: { isShowingHelpGuide = true },
                        proMembershipStatus: proMembershipStatus,
                        onProPurchaseTap: proMembershipStatus.isActive ? nil : { isShowingProUpgrade = true },
                        compactPanelMaxWidth: compactPanelMaxWidth,
                        availableContentWidth: contentWidth
                    )
                    .padding(.horizontal, outerHorizontalPadding)
                    .padding(.top, 52)
                    .padding(.bottom, isLandscape ? 8 : 12)
                }
                .safeAreaInset(edge: .bottom, spacing: 8) {
                    SettingsCreditFooter(text: AppBuildIdentity.settingsCreditMarqueeText)
                        .padding(.horizontal, outerHorizontalPadding)
                        .padding(.vertical, 10)
                }

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(JPadChromeTheme.primaryLabel)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.top, 12)
                .padding(.trailing, outerHorizontalPadding)
                .accessibilityLabel(L10n.string("settings.close.accessibility"))
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .jChordPopupSheetBackground()
        .jChordSheetOuterBorder()
        .fullScreenCover(isPresented: $isShowingHelpGuide) {
            GarageBandHelpView {
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
        .onAppear {
            midiService.refreshEndpoints(reconfigureSession: false)
            Task { await refreshProMembershipStatus() }
        }
        .onDisappear {
            midiService.setTestNoteEnabled(false)
            midiService.warmUpPreviewEngineIfNeeded()
        }
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
