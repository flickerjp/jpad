# ユーザー向けメッセージ一覧（整理メモ）

作成: 2026-05-19  
目的: アプリ／Web の表示文言を棚卸しし、日本語化の優先度検討用に残す。

**2026-05 実施**: 行頭 `X` / `X?` の削除候補を `ja.lproj` / `en.lproj` に反映済み（下表の ✓）。

## ソース

| 種別 | パス |
|------|------|
| 英語ベース | `JPad/Resources/en.lproj/Localizable.strings` |
| 日本語（部分上書き） | `JPad/Resources/ja.lproj/Localizable.strings` |
| ランタイム | `JPad/Shared/Localization/L10n.swift` |
| エラー文言（コード直書き） | `UserPresetLibraryError`, `JcstoreError`, `PresetShareError`, `PresetLoaderError`, `MidiNoteParseError` など |
| Web jcstore | `web/jcstore/index.html`, `web/jcstore/js/app.js` |

端末言語が **日本語** のとき: `ja.lproj` にキーがあればその値、なければ `en.lproj` にフォールバック。

---

## A. 日本語ロケールで日本語表示（#1–28）

### アプリ（`ja.lproj`）

| # | キー | 日本語表示 |
|---|------|------------|
✓ X? | 1 | `preset.picker.plan_test_label` | プラン（テスト） → ja 削除 |
✓ X? | 2 | `jcstore.published_at` | 公開 %@ → en/ja 削除（未使用） |
✓ X | 3 | `preset.library.default_title` | セットなし → ja 削除 |
✓ X | 4 | `preset.library.empty` | … → ja 削除 |
| 5 | `preset.library.slot_limit_notice` | 保存できるのは最大 %d 件までです。 |
✓ X? | 6 | `jcstore.open_web` | … → en/ja 削除（未使用） |
✓ X | 7 | `jcstore.replace_hint` | … → ja 削除 |
✓ X | 8 | `preset.io.new_blank.accessibility` | … → ja 削除 |
✓ X | 9 | `preset.io.duplicate.accessibility` | … → ja 削除 |
| 10 | `onboarding.title` | JChordへようこそ |
| 11 | `onboarding.subtitle` | GarageBandと連携して演奏を始めましょう |
| 12 | `onboarding.garageband.title` | GarageBand の設定 |
| 13 | `onboarding.garageband.step1` | GarageBand を開き、曲を新規作成するか、既存の曲を開きます。 |
| 14 | `onboarding.garageband.step2` | ソフトウェア楽器トラック（キーボード、シンセなど）を追加します。 |
| 15 | `onboarding.garageband.step3` | 右上の歯車 →「詳細」→「バックグラウンドで実行」をオンにします。 |
| 16 | `onboarding.garageband.step4` | JChord に戻り、PAD OUT で GarageBand（またはお使いの MIDI 機器）を選択します。 |
| 17 | `onboarding.garageband.step5` | TEST NOTE を押し続け、GarageBand に MIDI が届くことを確認します。 |
| 18 | `onboarding.continue` | JChord をはじめる |
| 19 | `onboarding.close` | 閉じる |
| 20 | `settings.midi_commands.accessibility` | Note On/Off 以外の MIDI を送信 |
| 21 | `settings.midi_command.midiStop` | MIDI Stop（シーケンス停止） |
| 22 | `settings.midi_command.sustainOff` | サステイン Off（現在 CH） |
| 23 | `settings.midi_command.panicCurrentChannel` | Panic（現在 CH） |
| 24 | `settings.midi_command.panicAllChannels` | Panic（全 CH + MIDI Stop） |
| 25 | `pad_editor.section.expanded.accessibility` | 展開 |
| 26 | `pad_editor.section.collapsed.accessibility` | 折りたたみ |

### Web（`web/jcstore/index.html`）

| # | 出所 | 日本語表示 |
|---|------|------------|
| 27 | `tagline` | 公式プリセットカタログ（デモ） |
| 28 | イントロ段落 | 既存の JChord バンドルプリセットを配信するデモサイトです。カードを開いてパッドを試聴し、iOS アプリの **プリセット一覧 → STORE** から同じ ID を取り込めます。… |

---

## B. `Localizable.strings`（日本語環境でも英語のまま）（#29–123）

`ja.lproj` にエントリが無い、または英語と同じ値。

### メイン画面（#29–38）

| # | キー | 表示 |
|---|------|------|
| 29 | `main.edit` | EDIT |
| 30 | `main.done` | DONE |
| 31 | `main.reset` | RESET |
| 32 | `main.hold` | HOLD |
| 33 | `main.velocity` | Velocity |
| 34 | `main.expression` | Expression |
| 35 | `main.midi_out.active.accessibility` | MIDI output connected |
| 36 | `main.midi_out.inactive.accessibility` | MIDI output not connected |
| 37 | `main.edit_pad_notes.accessibility` | Edit input notes |
| 38 | `main.edit_pad_label.accessibility` | Edit chord label and root |

### プリセット / MY SETS / STORE（#39–75）

| # | キー | 表示 |
|---|------|------|
| 39 | `preset.switch.accessibility` | Switch preset |
| 40 | `preset.rename.accessibility` | Rename set |
| 41 | `preset.picker.title` | Presets（通知アラートのタイトルにも使用） |
| 42 | `preset.picker.tab.my_sets` | MY SETS |
| 43 | `preset.picker.tab.store` | STORE |
| 44 | `preset.picker.close` | Close |
| 45 | `preset.library.origin_store_tag` | (Store) |
| 46 | `preset.picker.plan_free` | FREE |
| 47 | `preset.picker.plan_pro` | PRO |
✓ X | 48 | `preset.jazz_fusion` | Jazz Fusion → ja 重複削除 |
✓ X | 49 | `preset.bossa_nova` | Bossa Nova → ja 重複削除 |
✓ X | 50 | `preset.progressive_rock` | Progressive → ja 重複削除 |
✓ X | 51 | `preset.standard_jazz` | Standard Jazz → ja 重複削除 |
✓ X | 52 | `preset.city_pops` | City Pops → ja 重複削除 |
| 53 | `preset.my_stage` | My Stage |
| 54 | `preset.library.section` | MY SETS |
| 55 | `preset.library.slot_count` | %d / %d |
| 56 | `preset.library.origin.seed` | Starter |
| 57 | `preset.library.origin.store` | Store |
| 58 | `preset.library.copy_name` | %@ Copy |
| 59 | `preset.library.reseed` | Reset starter |
| 60 | `preset.library.delete` | Delete |
| 61 | `preset.io.new` | NEW |
| 62 | `preset.io.share` | SHARE |
| 63 | `preset.io.import` | IMPORT |
| 64 | `jcstore.title` | jcstore |
| 65 | `jcstore.section` | STORE |
| 66 | `jcstore.open` | Browse jcstore |
| 67 | `jcstore.close` | Close |
| 68 | `jcstore.empty` | No presets available |
| 69 | `preset.library.rename` | Rename |
| 70 | `preset.library.rename_title` | Rename Set |
| 71 | `preset.library.rename_placeholder` | Set name |
| 72 | `jcstore.replace_title` | Replace which set? |
| 73 | `preset.picker.delete` | Delete |
| 74 | `preset.io.load` | LOAD |
| 75 | `preset.io.save` | SAVE |

### 通知・アラート（#76–88）

| # | キー | 表示 | 使用 |
|---|------|------|------|
| 76 | `alert.reseed_success` | Starter template restored. | 使用中 |
| 77 | `alert.import_success` | Import complete. | 使用中 |
| 78 | `alert.share_requires_pro` | Sharing requires Pro. | 使用中 |
| 79 | `alert.preset_load_error` | Preset Load Error | 使用中（タイトル） |
| 80 | `alert.ok` | OK | 使用中 |
| 81 | `alert.new_slot_success` | New set created. | **未使用** |
| 82 | `alert.save_success` | Your pad set was saved. | **未使用** |
| 83 | `alert.load_success` | Your saved pad set was loaded. | **未使用** |
| 84 | `alert.save_requires_purchase` | Saving requires the Save unlock. | **未使用** |
| 85 | `alert.no_saved_set` | No saved pad set yet. Select My Stage and edit your pads. | **未使用** |
| 86 | `alert.cancel` | Cancel | **未使用** |
| 87 | `preset.my_stage.saved_hint` | Saved | **未使用** |
| 88 | `preset.bundled_all_removed_hint` | All factory presets were removed. Reinstall the app to restore them. | **未使用** |

### 設定 / MIDI（#89–110）

| # | キー | 表示 |
|---|------|------|
| 89 | `settings.help` | HELP |
| 90 | `settings.help.accessibility` | Open setup guide |
| 91 | `settings.close.accessibility` | Close |
| 92 | `settings.no_devices` | No Devices |
| 93 | `settings.device.active` | Active |
| 94 | `settings.device.connected` | Connected |
| 95 | `settings.device.offline` | Offline |
| 96 | `settings.pad_out` | PAD OUT |
| 97 | `settings.keyboard_in` | KEYBOARD IN |
| 98 | `settings.pad_out_ch` | PAD OUT CH |
| 99 | `settings.test_note` | TEST NOTE |
| 100 | `settings.test_note.accessibility` | Test note |
| 101 | `settings.midi_commands` | MIDI COMMANDS |
| 102 | `settings.midi_command.midiStart` | MIDI Start |
| 103 | `settings.midi_command.midiContinue` | MIDI Continue |
| 104 | `settings.midi_command.allSoundOff` | All Sound Off (current CH) |
| 105 | `settings.midi_command.allNotesOff` | All Notes Off (current CH) |
| 106 | `settings.midi_command.resetControllers` | Reset Controllers (current CH) |
| 107 | `settings.load` | LOAD |
| 108 | `settings.save` | SAVE |
| 109 | `settings.unlock` | UNLOCK |
| 110 | `settings.unlock.accessibility` | UNLOCK |

### パッドエディタ（#111–120）

| # | キー | 表示 |
|---|------|------|
| 111 | `pad_editor.label_section` | Label |
| 112 | `pad_editor.candidates` | Candidates |
| 113 | `pad_editor.root` | Root |
| 114 | `pad_editor.input_notes` | Input Notes |
| 115 | `pad_editor.input_notes.accessibility` | Input Notes |
| 116 | `pad_editor.cancel` | CANCEL |
| 117 | `pad_editor.set` | SET |
| 118 | `pad_editor.empty_notes` | — |
| 119 | `pad_editor.preview_note` | Note |
| 120 | `pad_editor.preview_note.accessibility` | Preview pad notes, hold to play |

### L10n エラー（#121）

| # | キー | 表示 |
|---|------|------|
| 121 | `error.no_midi_output` | No MIDI output selected |

---

## C. コード直書き・動的（#122–145）

| # | 出所 | 表示 |
|---|------|------|
| 122 | `Preset.blank` | Untitled |
| 123 | `Preset` デコード失敗時 | Untitled Preset |
| 124 | `Preset.fallback` | Preset |
| 125 | `PadEditorView` | [Chord name] |
| 126–127 | ノート削除 UI | × |
| 128–129 | オンボーディング / 設定フッター | JChord © 2026 FLICKER PRODUCT |
| 130 | `UserPresetLibraryError.slotNotFound` | Preset slot not found. |
| 131 | `UserPresetLibraryError.slotLimitReached` | Up to {n} sets can be saved. |
| 132 | `UserPresetLibraryError.storeImportLimitReached` | All slots are full. Choose a set to replace with this store import. |
| 133 | `UserPresetLibraryError.noActiveSlot` | No active preset slot. |
| 134 | `UserPresetLibraryError.emptyLibrary` | Preset library is empty. |
| 135 | `JcstoreError.*` | jcstore manifest is unavailable. / Preset is not listed in jcstore. / … |
| 136 | `PresetShareError.*` | Sharing requires Pro. / Only user-created sets can be shared. / … |
| 137 | `PresetLoaderError.*` | Could not find bundled preset… / Could not decode… |
| 138 | `MidiNoteParseError.*` | Note value is empty. / Could not parse note… / … |
| 139 | `MainView` `presetErrorMessage` | 上記エラー等の `localizedDescription` |
| 140 | スロット一覧のセット名 | ユーザー入力・バンドル名 |
| 141 | 複製名 | `{セット名} Copy`（`preset.library.copy_name`） |
| 142 | STORE 行 | `公開 {日付} (Store)` 形式 |
| 143–144 | パッド | `label`（コード名）/ `displayName`（ルート音名） |

---

## D. Web jcstore（英語中心）（#145–151）

| # | 出所 | 表示 |
|---|------|------|
| 145 | `index.html` title | jcstore — JChord Presets |
| 146 | MIDI 初期 | MIDI: checking… |
| 147 | `app.js` | Web MIDI not supported… / No MIDI output… / MIDI out: {name} |
| 148 | 読込中 | Loading manifest… / Loading pads… |
| 149 | エラー | Failed to load preset: … |
| 150 | `manifest.json` description | 各プリセット英語説明 |
| 151 | フッター | © FLICKER PRODUCT · Demo host path `/jcstore/` |

---

## 実際に出る通知（`MainView`）

| 種別 | タイトル | 本文の例 |
|------|----------|----------|
| エラー | `alert.preset_load_error` | #130–139 |
| お知らせ | `preset.picker.title`（Presets） | #5, #76–78, `slot_limit_notice` |

---

## 日本語化の優先候補（メモ）

1. MY SETS 周り: #4–5, #59–72, #76–78  
2. エラー: #130–138 を `Localizable` 化  
3. 未使用キー: #81–88 は翻訳前に削除 or 実装を接続するか決める  
4. UI 方針: ボタンラベル（EDIT / STORE 等）を日英どちらに揃えるか product 判断  

---

## 更新手順（将来）

1. `en.lproj/Localizable.strings` にキー追加  
2. 必要なら `ja.lproj` に上書き  
3. `docs/LOCALIZATION_MESSAGES.md` の該当行を更新  
