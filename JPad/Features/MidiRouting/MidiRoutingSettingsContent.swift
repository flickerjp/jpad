import SwiftUI

/// PAD OUT 以降の MIDI ルーティング UI（設定画面・初回オンボーディングで共有）。
struct MidiRoutingSettingsContent: View {
    enum Presentation {
        case settings
        case welcome
    }

    @ObservedObject var midiService: MidiOutputService
    @AppStorage(PadVisualStyleSettings.storageKey) private var padVisualStyleRaw = PadVisualStyle.dark.rawValue
    @AppStorage(MidiClockReceiver.tempoSourceStorageKey) private var isExternalClockOn = false
    let testPadWidth: CGFloat
    var presentation: Presentation = .settings
    var onHelpTapped: (() -> Void)? = nil
    var proMembershipStatus: ProSubscriptionStatus? = nil
    /// 未購入時に JPad Pro 購入画面へ遷移
    var onProPurchaseTap: (() -> Void)? = nil
    /// 横画面などで TEST NOTE / Buy 行を左半分に収める最大幅
    var compactPanelMaxWidth: CGFloat? = nil
    /// ScrollView の実効コンテンツ幅。iPhone 幅で固定列がはみ出さないように使う。
    var availableContentWidth: CGFloat? = nil
    /// ARP / SEQ のテンポ源（内部 BPM / MIDI Clock 追従）切替の通知先。
    var onClockSourceChanged: ((Bool) -> Void)? = nil
    /// ARP / SEQ 共通の内部テンポ。MIDI Clock 選択中は保持値として表示する。
    var internalClockBpm: Binding<Int>? = nil

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
            settingsCard {
                previewSoundPresetRow
            }

            settingsCard {
                primaryPadOutputModeRadioRow
            }

            if showsDeviceRouting {
                settingsCard {
                    fieldTitle(L10n.string("settings.pad_out"))
                    deviceSection(
                        items: midiService.padOutSectionChoices.map { padOutputChoiceItem($0) },
                        onSelect: { midiService.selectPadOutput(uniqueID: $0) },
                        onSelectedTap: { _ in
                            midiService.playTestNotePulse()
                        },
                        selectedItemsUseActiveStyle: true
                    )

                    // GarageBand ルートが Active にならないときだけ診断を出す（原因の切り分け用）
                    if midiService.outputRoute == .garageBand, !midiService.isGarageBandRouteReady {
                        Text(midiService.garageBandDiagnosticDescription)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(JPadChromeTheme.accentLight)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
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
                settingsLabelValueRow(label: L10n.string("settings.midi_out")) {
                    JChordMidiChannelWheelPicker(
                        channel: Binding(
                            get: { midiService.midiChannel },
                            set: { midiService.updateMidiChannel($0) }
                        ),
                        width: midiChannelPickerWidth,
                        height: settingsActionButtonHeight
                    )
                }
            }

            settingsCard {
                clockSourceRadioRow
            }

            settingsCard {
                settingsLabelValueRow(label: L10n.string("settings.pad_style")) {
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
        VStack(spacing: 12) {
            settingsCard {
                fieldTitle(L10n.string("onboarding.sound"))
                welcomeSoundAndNoteRow
            }

            settingsCard {
                primaryPadOutputModeRadioRow
            }

            settingsCard {
                fieldTitle(L10n.string("settings.pad_style"))
                welcomePadStylePicker
            }
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

    /// TEST NOTE / Buy 共通幅（パッド cellSide）
    private var settingsActionButtonWidth: CGFloat { testPadWidth }

    /// Buy の高さ基準。TEST NOTE も同じ高さに揃える。
    private var settingsActionButtonHeight: CGFloat { 32 }

    private var settingsCardContentWidth: CGFloat {
        let baseWidth = compactPanelMaxWidth ?? availableContentWidth ?? 340
        return max(248, baseWidth - 32)
    }

    /// 左列の固定幅。TinyTone と各ラベルの縦ラインを揃える。
    private var settingsLabelColumnWidth: CGFloat {
        let preferred = min(max(settingsActionButtonWidth + 18, 96), 120)
        return min(preferred, max(82, settingsGridWidth - 12 - 148))
    }

    /// カード内の 2 カラムブロック全幅。
    private var settingsGridWidth: CGFloat {
        min(settingsCardContentWidth, 336)
    }

    /// 右列の固定幅。TEST NOTE / 1CH は左詰め、DARK/FLASH は全幅使用。
    private var settingsControlColumnWidth: CGFloat {
        max(148, settingsGridWidth - settingsLabelColumnWidth - 12)
    }

    private var midiChannelPickerWidth: CGFloat {
        max(settingsActionButtonWidth, 74)
    }

    private func settingsLabelValueRow<Control: View>(
        label: String,
        @ViewBuilder control: () -> Control
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(label)
                .font(.caption.weight(.heavy))
                .foregroundStyle(JChordTheme.muted)
                .frame(width: settingsLabelColumnWidth, alignment: .leading)

            control()
                .frame(width: settingsControlColumnWidth, alignment: .leading)
        }
        .frame(width: settingsGridWidth, alignment: .leading)
    }

    private var isTinyTonePadOutActive: Bool {
        midiService.outputRoute == .tinyPiano
    }

    private var isGarageBandPadOutActive: Bool {
        midiService.outputRoute == .garageBand
    }

    private var previewSoundPresetRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldTitle(L10n.string("settings.preview_sound.label"))

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
                            .foregroundStyle(
                                isTinyTonePadOutActive
                                    ? JChordTheme.text
                                    : JChordTheme.muted.opacity(0.45)
                            )
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(
                                isTinyTonePadOutActive
                                    ? JPadChromeTheme.accentLight
                                    : JChordTheme.muted.opacity(0.35)
                            )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .disabled(!isTinyTonePadOutActive)
                .frame(width: settingsLabelColumnWidth, alignment: .leading)
                .accessibilityLabel(L10n.string("settings.preview_sound.picker.accessibility"))

                HStack(spacing: 0) {
                    JChordTestNotePadButton(
                        isMidiOutputActive: isTinyTonePadOutActive,
                        width: settingsActionButtonWidth,
                        height: settingsActionButtonHeight
                    ) { isPressed in
                        midiService.setTestNoteEnabled(isPressed)
                    }
                    .allowsHitTesting(isTinyTonePadOutActive)
                    .opacity(isTinyTonePadOutActive ? 1 : 0.42)

                    Button {
                        midiService.reloadPreviewSoundPresetOptions()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: settingsActionButtonHeight * 0.72, weight: .semibold))
                            .foregroundStyle(
                                isTinyTonePadOutActive
                                    ? JChordTheme.text
                                    : JChordTheme.muted.opacity(0.45)
                            )
                            .frame(width: settingsActionButtonHeight * 1.2, height: settingsActionButtonHeight)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!isTinyTonePadOutActive)
                    .opacity(isTinyTonePadOutActive ? 1 : 0.42)
                    .padding(.leading, 10)
                    .accessibilityLabel(L10n.string("settings.preview_sound.reload.accessibility"))

                    Spacer(minLength: 0)
                }
                .frame(width: settingsControlColumnWidth, alignment: .leading)
            }
            .frame(width: settingsGridWidth, alignment: .leading)
            .accessibilityElement(children: .contain)

            if isTinyTonePadOutActive, !midiService.isInternalPreviewReady {
                Text(midiService.lastMidiEventDescription)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(JPadChromeTheme.accentLight)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(width: settingsGridWidth, alignment: .leading)
    }

    private var primaryPadOutputModeRadioRow: some View {
        HStack(spacing: 14) {
            primaryPadOutputModeRadioButton(
                title: L10n.string("settings.pad_out.tiny_piano"),
                isSelected: isTinyTonePadOutActive
            ) {
                if isTinyTonePadOutActive {
                    midiService.playTestNotePulse()
                } else {
                    midiService.selectPrimaryPadOutputMode(.tinyTone)
                }
            }

            primaryPadOutputModeRadioButton(
                title: L10n.string("settings.primary_pad_out.garage_band"),
                isSelected: isGarageBandPadOutActive
            ) {
                if isGarageBandPadOutActive {
                    midiService.playTestNotePulse()
                } else {
                    midiService.selectPrimaryPadOutputMode(.garageBand)
                }
            }

            Spacer(minLength: 0)
        }
        .frame(width: settingsGridWidth, alignment: .leading)
        .accessibilityElement(children: .contain)
    }

    /// ARP / SEQ のテンポ源。内部 BPM か MIDI Clock (24 ppqn) 追従か。
    private var clockSourceRadioRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldTitle(L10n.string("settings.clock_source"))
            HStack(spacing: 12) {
                primaryPadOutputModeRadioButton(
                    title: L10n.string("settings.clock_source.midi_clock"),
                    isSelected: isExternalClockOn
                ) {
                    guard !isExternalClockOn else { return }
                    isExternalClockOn = true
                    onClockSourceChanged?(true)
                }

                HStack(spacing: 6) {
                    primaryPadOutputModeRadioButton(
                        title: L10n.string("settings.clock_source.internal"),
                        isSelected: !isExternalClockOn
                    ) {
                        guard isExternalClockOn else { return }
                        isExternalClockOn = false
                        onClockSourceChanged?(false)
                    }

                    if let internalClockBpm {
                        JChordValueWheelPicker(
                            values: Array(stride(from: Int(PresetSequencerSettings.bpmRange.upperBound), through: Int(PresetSequencerSettings.bpmRange.lowerBound), by: -1)),
                            value: internalClockBpm,
                            width: min(78, max(64, settingsControlColumnWidth - 112)),
                            height: settingsActionButtonHeight,
                            displayText: { "\($0)" }
                        )
                        .opacity(isExternalClockOn ? 0.45 : 1)
                        .disabled(isExternalClockOn)
                    }
                }

                Spacer(minLength: 0)
            }
        }
        .frame(width: settingsGridWidth, alignment: .leading)
        .accessibilityElement(children: .contain)
    }

    private func primaryPadOutputModeRadioButton(
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 15, weight: .semibold))
                Text(title)
                    .font(.system(size: 15, weight: .heavy))
            }
            .foregroundStyle(isSelected ? JChordTheme.text : JChordTheme.muted)
            .padding(.horizontal, 2)
            .frame(height: 28)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
            proStatusInfoRow(status)
        }
    }

    private func proStatusInfoRow(_ status: ProSubscriptionStatus) -> some View {
        Group {
            if !status.isActive, let onProPurchaseTap {
                HStack(spacing: 14) {
                    Text(proStatusSummary(status))
                        .font(.system(size: proStatusLabelFontSize, weight: .heavy))
                        .foregroundStyle(JChordTheme.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    proPurchaseButton(action: onProPurchaseTap)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            } else {
                HStack {
                    Spacer(minLength: 0)
                    Text(proStatusSummary(status))
                        .font(.system(size: proStatusLabelFontSize, weight: .heavy))
                        .foregroundStyle(JChordTheme.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    Spacer(minLength: 0)
                }
            }
        }
        .frame(width: settingsGridWidth, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(status.accessibilityLabel)
    }

    private func proStatusSummary(_ status: ProSubscriptionStatus) -> String {
        guard let dateRow = status.dateRow else {
            return status.statusLabel
        }
        return "\(status.statusLabel)\u{00A0}\u{00A0}\u{00A0}\u{00A0}\(dateRow.label)：\(dateRow.date)"
    }

    private var proStatusLabelFontSize: CGFloat { 15 }

    private func proPurchaseButton(action: @escaping () -> Void) -> some View {
        JPadChromeDockButton(
            title: L10n.string("pro.picker.purchase"),
            style: .accentToggle,
            isOn: true,
            size: .standard,
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
        .frame(width: settingsControlColumnWidth)
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
        let isGarageBandRow = choice.uniqueID == MidiOutputService.garageBandUniqueID
        let isSelected: Bool
        let isActiveRoute: Bool
        if isGarageBandRow {
            isSelected = midiService.outputRoute == .garageBand
            isActiveRoute = isSelected && midiService.isGarageBandRouteReady
        } else {
            isSelected = midiService.outputRoute == .device
                && choice.uniqueID == midiService.effectiveSelectedPadOutputUniqueID
            isActiveRoute = isSelected && choice.isOnline
        }
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
        onSelectedTap: ((Int32) -> Void)? = nil,
        selectedItemsUseActiveStyle: Bool = false
    ) -> some View {
        VStack(spacing: 8) {
            if items.isEmpty {
                Text(L10n.string("settings.no_devices"))
                    .font(.caption)
                    .foregroundStyle(JChordTheme.muted)
            } else {
                ForEach(items) { item in
                    let canTap = item.isOnline && (item.isSelectable || item.isSelected)
                    Button {
                        if item.isSelected {
                            if let onSelectedTap {
                                onSelectedTap(item.id)
                            } else {
                                onSelect(item.id)
                            }
                        } else {
                            onSelect(item.id)
                        }
                    } label: {
                        JChordDeviceRow(
                            title: item.title,
                            subtitle: item.subtitle,
                            isSelected: selectedItemsUseActiveStyle ? false : item.isSelected && !item.isActiveRoute,
                            isReceiving: item.isActiveRoute || (selectedItemsUseActiveStyle && item.isSelected),
                            isEnabled: canTap
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!canTap)
                }
            }
        }
    }
}
