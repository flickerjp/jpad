import SwiftUI

/// PAD OUT 以降の MIDI ルーティング UI（設定画面・初回オンボーディングで共有）。
struct MidiRoutingSettingsContent: View {
    @ObservedObject var midiService: MidiOutputService
    @AppStorage(PadVisualStyleSettings.storageKey) private var padVisualStyleRaw = PadVisualStyle.dark.rawValue
    let testPadWidth: CGFloat
    var onHelpTapped: (() -> Void)? = nil
    var onPreviewSoundLoadTapped: (() -> Void)? = nil
    var proMembershipStatus: ProSubscriptionStatus? = nil
    /// 未購入時に JPad Pro 購入画面へ遷移
    var onProPurchaseTap: (() -> Void)? = nil
    /// 横画面などで TEST NOTE / Buy 行を左半分に収める最大幅
    var compactPanelMaxWidth: CGFloat? = nil

    var body: some View {
        VStack(spacing: 12) {
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
                        .foregroundStyle(Color.orange.opacity(0.9))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                fieldTitle(L10n.string("settings.keyboard_in"))
                    .padding(.top, 6)
                deviceSection(
                    items: midiService.filteredKeyboardInputs.map { keyboardInputDeviceItem($0) },
                    onSelect: { midiService.selectKeyboardInput(uniqueID: $0) }
                )
            }

            settingsCard {
                previewSoundPresetRow
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
            .frame(width: settingsActionButtonWidth)

            JChordTestNotePadButton(
                isMidiOutputActive: midiService.hasActiveMidiOutput,
                width: settingsActionButtonWidth,
                height: settingsActionButtonHeight
            ) { isPressed in
                midiService.setTestNoteEnabled(isPressed)
            }
        }
        .frame(width: settingsControlsRowWidth)
    }

    private func settingsControlsRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .center)
    }

    /// 内側パネル（JPAD 購入行）の左右余白
    private var settingsCardInnerHorizontalInset: CGFloat { 14 }

    private var previewSoundPresetRow: some View {
        HStack(alignment: .center, spacing: 10) {
            Picker(
                "",
                selection: Binding(
                    get: { midiService.selectedPreviewSoundPresetID },
                    set: { midiService.selectPreviewSoundPreset(id: $0) }
                )
            ) {
                ForEach(midiService.previewSoundPresetOptions) { option in
                    Text(option.displayName).tag(option.id)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .tint(JChordTheme.text)
            .frame(maxWidth: .infinity, alignment: .leading)

            if let onPreviewSoundLoadTapped {
                Button(action: onPreviewSoundLoadTapped) {
                    Text(L10n.string("settings.load"))
                }
                .buttonStyle(
                    JChordNoteOffStyle(
                        isLocked: true,
                        lockedForegroundOpacity: 0.8,
                        fontSize: 13,
                        height: settingsActionButtonHeight,
                        fixedWidth: settingsActionButtonWidth
                    )
                )
                .accessibilityLabel(L10n.string("settings.preview_sound.load.accessibility"))
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L10n.string("settings.preview_sound.picker.accessibility"))
    }

    private func footerActions(onHelpTapped: @escaping () -> Void) -> some View {
        Button(action: onHelpTapped) {
            Text(L10n.string("settings.help"))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(JChordTheme.muted)
                .underline()
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
                            .font(.subheadline.weight(.heavy))
                            .foregroundStyle(JChordTheme.text)
                        proPurchaseButton(action: onProPurchaseTap)
                    }
                    .frame(maxWidth: compactPanelMaxWidth, alignment: .leading)
                } else {
                    HStack(alignment: .center, spacing: 0) {
                        Text(status.statusLabel)
                            .font(.subheadline.weight(.heavy))
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

    private func proPurchaseButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(L10n.string("pro.picker.purchase"))
        }
        .buttonStyle(
            JChordNoteOffStyle(
                isActive: true,
                fontSize: 14,
                height: settingsActionButtonHeight,
                fixedWidth: settingsActionButtonWidth
            )
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
