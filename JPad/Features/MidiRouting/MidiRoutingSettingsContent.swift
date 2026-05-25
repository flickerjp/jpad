import SwiftUI

/// PAD OUT 以降の MIDI ルーティング UI（設定画面・初回オンボーディングで共有）。
struct MidiRoutingSettingsContent: View {
    enum Presentation {
        case settings
        case welcome
    }

    @ObservedObject var midiService: MidiOutputService
    @AppStorage(PadVisualStyleSettings.storageKey) private var padVisualStyleRaw = PadVisualStyle.dark.rawValue
    let testPadWidth: CGFloat
    var presentation: Presentation = .settings
    var onHelpTapped: (() -> Void)? = nil
    var onPreviewSoundLoadTapped: (() -> Void)? = nil
    var proMembershipStatus: ProSubscriptionStatus? = nil
    /// 未購入時に JPad Pro 購入画面へ遷移
    var onProPurchaseTap: (() -> Void)? = nil
    /// 横画面などで TEST NOTE / Buy 行を左半分に収める最大幅
    var compactPanelMaxWidth: CGFloat? = nil

    private var showsDeviceRouting: Bool { presentation == .settings }

    var body: some View {
        switch presentation {
        case .welcome:
            welcomeSettingsBody
        case .settings:
            settingsBody
        }
    }

    private var settingsBody: some View {
        VStack(spacing: 12) {
            if showsDeviceRouting {
                settingsCard {
                    fieldTitle(L10n.string("settings.pad_out"))
                    deviceSection(
                        items: midiService.padOutputChoices.map { padOutputChoiceItem($0) },
                        onSelect: { midiService.selectPadOutput(uniqueID: $0) },
                        selectedItemsUseActiveStyle: true
                    )

                    if midiService.outputRoute == .tinyPiano, !midiService.isInternalPreviewReady {
                        Text(midiService.lastMidiEventDescription)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(JPadChromeTheme.accentLight)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    fieldTitle(L10n.string("settings.keyboard_in"))
                        .padding(.top, 6)
                    deviceSection(
                        items: midiService.filteredKeyboardInputs.map { keyboardInputDeviceItem($0) },
                        onSelect: { midiService.selectKeyboardInput(uniqueID: $0) }
                    )
                }
            }

            settingsCard {
                settingsControlsRow {
                    previewSoundPresetRow
                }
            }

            settingsCard {
                fieldTitle(L10n.string("settings.pad_out_ch"))
                settingsControlsRow {
                    midiOutAndTestNoteControls
                }
                fieldTitle(L10n.string("settings.pad_style"))
                    .padding(.top, 4)
                settingsControlsRow {
                    padStylePicker
                }
            }

            if let proMembershipStatus {
                proMembershipCard(proMembershipStatus)
            }

            if let onHelpTapped {
                footerActions(onHelpTapped: onHelpTapped)
            }
        }
        .frame(maxWidth: compactPanelMaxWidth ?? .infinity, alignment: .leading)
    }

    private var welcomeSettingsBody: some View {
        settingsCard {
            fieldTitle(L10n.string("onboarding.sound"))
            welcomeSoundAndNoteRow

            fieldTitle(L10n.string("settings.pad_style"))
                .padding(.top, 8)
            welcomePadStylePicker
        }
        .frame(maxWidth: welcomePanelMaxWidth, alignment: .center)
    }

    private var welcomePanelMaxWidth: CGFloat {
        min(max(testPadWidth * 3.2, 300), 380)
    }

    private var welcomeSoundAndNoteRow: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            HStack(alignment: .center, spacing: 10) {
                Menu {
                    ForEach(midiService.previewSoundPresetOptions) { option in
                        Button(option.displayName) {
                            midiService.selectPreviewSoundPreset(id: option.id)
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(selectedPreviewSoundName)
                            .font(.system(size: 22, weight: .heavy))
                            .foregroundStyle(JChordTheme.text)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(JPadChromeTheme.accentLight)
                    }
                }
                .accessibilityLabel(L10n.string("settings.preview_sound.picker.accessibility"))

                JChordTestNotePadButton(
                    titleKey: "onboarding.note",
                    appearance: .welcomeCompact
                ) { isPressed in
                    midiService.setTestNoteEnabled(isPressed)
                }
                .accessibilityLabel(L10n.string("onboarding.note.accessibility"))
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }

    private var selectedPreviewSoundName: String {
        midiService.previewSoundPresetOptions
            .first(where: { $0.id == midiService.selectedPreviewSoundPresetID })?
            .displayName ?? L10n.string("settings.preview_sound.label")
    }

    private var welcomePadStylePicker: some View {
        HStack(spacing: 10) {
            welcomePadStyleOption(
                style: .dark,
                title: L10n.string("settings.pad_style.dark")
            )
            welcomePadStyleOption(
                style: .performance,
                title: L10n.string("settings.pad_style.performance")
            )
        }
    }

    private func welcomePadStyleOption(style: PadVisualStyle, title: String) -> some View {
        let metrics = JPadOrangeChromeStyle.metrics(for: .standard)
        let isSelected = padStyleBinding.wrappedValue == style
        return Button {
            padStyleBinding.wrappedValue = style
        } label: {
            Text(title)
                .font(.system(size: metrics.fontSize, weight: metrics.fontWeight))
                .foregroundStyle(
                    isSelected
                        ? JPadOrangeChromeStyle.foreground(isPressed: false, isAccentOn: false)
                        : JPadOrangeChromeStyle.unselectedGreyForeground()
                )
                .frame(maxWidth: .infinity)
                .frame(height: metrics.height)
                .background(
                    isSelected
                        ? JPadOrangeChromeStyle.background(isPressed: false, isAccentOn: false)
                        : JPadOrangeChromeStyle.unselectedGreyBackground(),
                    in: Capsule(style: .continuous)
                )
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(
                            isSelected
                                ? JPadOrangeChromeStyle.border(isPressed: false, isAccentOn: false)
                                : JPadOrangeChromeStyle.unselectedGreyBorder(),
                            lineWidth: 1
                        )
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var usesCompactLeadingLayout: Bool {
        compactPanelMaxWidth != nil
    }

    /// TEST NOTE / Buy 共通幅（パッド cellSide）
    private var settingsActionButtonWidth: CGFloat { testPadWidth }

    /// Buy の高さ基準。TEST NOTE も同じ高さに揃える。
    private var settingsActionButtonHeight: CGFloat { 32 }

    /// チャンネル＋TEST NOTE と PAD STYLE で共通（中央揃えブロック幅）
    private var settingsControlsRowWidth: CGFloat {
        max(settingsActionButtonWidth * 2 + 12, 200)
    }

    /// プリセット名（TinyStrings 等）が折り返さない左列幅
    private var presetPickerColumnWidth: CGFloat {
        max(settingsActionButtonWidth, 132)
    }

    /// LOAD / TEST NOTE の右列を揃えた行幅
    private var settingsAlignedRowWidth: CGFloat {
        max(settingsControlsRowWidth, presetPickerColumnWidth + 12 + settingsActionButtonWidth)
    }

    private var settingsLeadingColumnWidth: CGFloat {
        settingsAlignedRowWidth - 12 - settingsActionButtonWidth
    }

    private var midiOutAndTestNoteControls: some View {
        HStack(alignment: .bottom, spacing: 12) {
            JChordMidiChannelWheelPicker(
                channel: Binding(
                    get: { midiService.midiChannel },
                    set: { midiService.updateMidiChannel($0) }
                ),
                width: settingsActionButtonWidth,
                height: settingsActionButtonHeight
            )
            .frame(width: settingsLeadingColumnWidth)

            JChordTestNotePadButton(
                isMidiOutputActive: midiService.hasActiveMidiOutput,
                width: settingsActionButtonWidth
            ) { isPressed in
                midiService.setTestNoteEnabled(isPressed)
            }
        }
        .frame(width: settingsAlignedRowWidth)
    }

    private func settingsControlsRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .center)
    }

    /// 内側パネル（JPAD 購入行）の左右余白
    private var settingsCardInnerHorizontalInset: CGFloat { 14 }

    private var previewSoundPresetRow: some View {
        HStack(alignment: .center, spacing: 12) {
            Menu {
                ForEach(midiService.previewSoundPresetOptions) { option in
                    Button(option.displayName) {
                        midiService.selectPreviewSoundPreset(id: option.id)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(selectedPreviewSoundName)
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(JChordTheme.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(JPadChromeTheme.accentLight)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(width: settingsLeadingColumnWidth, alignment: .leading)
            .accessibilityLabel(L10n.string("settings.preview_sound.picker.accessibility"))

            if let onPreviewSoundLoadTapped {
                JPadChromeDockButton(
                    title: L10n.string("settings.load"),
                    style: .outline,
                    size: .compact,
                    width: settingsActionButtonWidth,
                    action: onPreviewSoundLoadTapped
                )
                .accessibilityLabel(L10n.string("settings.preview_sound.load.accessibility"))
            }
        }
        .frame(width: settingsAlignedRowWidth)
        .accessibilityElement(children: .contain)
    }

    private func footerActions(onHelpTapped: @escaping () -> Void) -> some View {
        Button(action: onHelpTapped) {
            Text(L10n.string("help.garageband.title"))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(JChordTheme.muted)
                .underline()
                .multilineTextAlignment(.center)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 2)
        .accessibilityLabel(L10n.string("settings.help.accessibility"))
    }

    private func proMembershipCard(_ status: ProSubscriptionStatus) -> some View {
        settingsCard {
            fieldTitle(L10n.string("settings.pro.section_title"))
            proStatusInfoRow(status)
        }
    }

    private func proStatusInfoRow(_ status: ProSubscriptionStatus) -> some View {
        Group {
            if !status.isActive, let onProPurchaseTap {
                if usesCompactLeadingLayout {
                    HStack(alignment: .center, spacing: 12) {
                        Text(status.statusLabel)
                            .font(.system(size: proStatusLabelFontSize, weight: .heavy))
                            .foregroundStyle(JChordTheme.text)
                        proPurchaseButton(action: onProPurchaseTap)
                    }
                    .frame(maxWidth: compactPanelMaxWidth, alignment: .leading)
                } else {
                    HStack(alignment: .center, spacing: 0) {
                        Text(status.statusLabel)
                            .font(.system(size: proStatusLabelFontSize, weight: .heavy))
                            .foregroundStyle(JChordTheme.text)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .multilineTextAlignment(.center)
                        HStack(spacing: 0) {
                            Spacer(minLength: 0)
                            proPurchaseButton(action: onProPurchaseTap)
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text(status.statusLabel)
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(JChordTheme.text)

                    if let dateRow = status.dateRow {
                        HStack(alignment: .firstTextBaseline) {
                            Text(dateRow.label)
                            Spacer(minLength: 12)
                            Text(dateRow.date)
                        }
                        .font(.caption.weight(.bold))
                        .foregroundStyle(JChordTheme.text.opacity(0.92))
                    } else if status.isActive {
                        Text(L10n.string("settings.pro.active_fallback"))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(JChordTheme.text.opacity(0.92))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, settingsCardInnerHorizontalInset)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(status.accessibilityLabel)
    }

    private var proStatusLabelFontSize: CGFloat { 15 }

    private func proPurchaseButton(action: @escaping () -> Void) -> some View {
        JPadChromeDockButton(
            title: L10n.string("pro.picker.purchase"),
            style: .accentToggle,
            isOn: true,
            size: .compact,
            fontSize: proStatusLabelFontSize + 2,
            width: settingsActionButtonWidth,
            action: action
        )
        .fixedSize()
        .accessibilityLabel(L10n.string("pro.picker.purchase.accessibility"))
    }

    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10, content: content)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(JChordTheme.panel, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            )
    }

    private func fieldTitle(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.heavy))
            .foregroundStyle(JChordTheme.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .multilineTextAlignment(.leading)
    }

    private var padStyleBinding: Binding<PadVisualStyle> {
        Binding(
            get: { PadVisualStyle(rawValue: padVisualStyleRaw) ?? PadVisualStyleSettings.defaultStyle },
            set: { padVisualStyleRaw = $0.rawValue }
        )
    }

    private var padStylePicker: some View {
        Picker("", selection: padStyleBinding) {
            Text(L10n.string("settings.pad_style.dark")).tag(PadVisualStyle.dark)
            Text(L10n.string("settings.pad_style.performance")).tag(PadVisualStyle.performance)
        }
        .pickerStyle(.segmented)
        .frame(width: settingsControlsRowWidth)
        .accessibilityLabel(L10n.string("settings.pad_style.accessibility"))
    }

    private struct DeviceItem: Identifiable {
        let id: Int32
        let title: String
        let subtitle: String
        let isOnline: Bool
        let isSelectable: Bool
        let isSelected: Bool
        let isActiveRoute: Bool
    }

    private func padOutputChoiceItem(_ choice: MidiPadOutputChoice) -> DeviceItem {
        let isSelected = choice.uniqueID == midiService.effectiveSelectedPadOutputUniqueID
        let isActiveRoute = isSelected && choice.isOnline
        return DeviceItem(
            id: choice.uniqueID,
            title: choice.title,
            subtitle: choice.subtitle,
            isOnline: choice.isOnline,
            isSelectable: choice.isSelectable,
            isSelected: isSelected,
            isActiveRoute: isActiveRoute
        )
    }

    private func keyboardInputDeviceItem(_ source: MidiSourceInfo) -> DeviceItem {
        let isSelected = source.uniqueID == midiService.effectiveSelectedKeyboardInputUniqueID
        let isActiveRoute = isSelected && source.isOnline
        return DeviceItem(
            id: source.uniqueID,
            title: MidiOutputService.friendlyListTitle(forKeyboardInput: source.displayName),
            subtitle: deviceStatusLabel(isOnline: source.isOnline, isSelected: isSelected, isActiveRoute: isActiveRoute),
            isOnline: source.isOnline,
            isSelectable: source.isOnline,
            isSelected: isSelected,
            isActiveRoute: isActiveRoute
        )
    }

    private func deviceStatusLabel(isOnline: Bool, isSelected: Bool, isActiveRoute: Bool) -> String {
        if !isOnline {
            return L10n.string("settings.device.offline")
        }
        if isActiveRoute {
            return L10n.string("settings.device.active")
        }
        if isSelected {
            return L10n.string("settings.device.connected")
        }
        return L10n.string("settings.device.connected")
    }

    private func deviceSection(
        items: [DeviceItem],
        onSelect: @escaping (Int32) -> Void,
        selectedItemsUseActiveStyle: Bool = false
    ) -> some View {
        VStack(spacing: 8) {
            if items.isEmpty {
                Text(L10n.string("settings.no_devices"))
                    .font(.caption)
                    .foregroundStyle(JChordTheme.muted)
            } else {
                ForEach(items) { item in
                    Button {
                        onSelect(item.id)
                    } label: {
                        JChordDeviceRow(
                            title: item.title,
                            subtitle: item.subtitle,
                            isSelected: selectedItemsUseActiveStyle ? false : item.isSelected && !item.isActiveRoute,
                            isReceiving: item.isActiveRoute || (selectedItemsUseActiveStyle && item.isSelected),
                            isEnabled: item.isOnline && item.isSelectable
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!item.isOnline || !item.isSelectable)
                }
            }
        }
    }
}
