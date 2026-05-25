# JPad UI 設計・ビジュアル仕様

アプリ表示名 **JPad**（App Store / ホーム画面は `JChord MIDI` 等の Connect 設定に依存）。  
実装の正本: `JPad/Shared/Design/JChordTheme.swift` および各 Feature の View。

## カラートークン（`JChordTheme`）

| トークン | 用途 | 定義 |
|--------|------|------|
| `background` | メイン画面・購入シート内スクロール | 上 `0.05,0.07,0.11` → 下 `0.03,0.04,0.07` のグラデーション |
| `panel` | カード・リスト行・パッド編集カード | `rgb(0.08,0.11,0.17)` opacity 0.96（**白ブレンドなし**） |
| `popupPanel` | シート外枠・Input Notes 面板・Presets の外周/フッター/＋行 | `panel` に **白 5%** を RGB 加算した色（opacity 0.98） |
| `text` / `muted` | 本文 / 補助 | クリーム系白 |
| `accentOrange*` | アクティブパッド・HOLD・購入 CTA | 暖色オレンジグラデーション |
| `unlockProminentTint` | 購入ボタン（未購入時の LOAD/SAVE 相当） | オレンジ単色 |

### 枠線

| スタイル | 色・太さ | 適用 |
|--------|---------|------|
| `popupPanelBorderStyle()` | 白 50%・**1.5pt** | フローティング POPUP・**iPad のみ**のシート外周 |
| `padBorder` / パッド枠 | 白 50% | コードパッド |
| `padActionBorder` | 白 35% | RESET / HOLD / SHARE / IMPORT |
| `settingsCard` 内枠 | 白 8% | 設定・オンボーディングのカード |

## シート・ポップアップの chrome

### 共通 API

| Modifier | 背景 | 白枠 | 備考 |
|----------|------|------|------|
| `jChordScreenBackground()` | `background` グラデーション | なし | メイン・購入シート本文 |
| `jChordPopupSheetBackground(brightPanel:)` | `popupPanel`（既定）または `panel` | なし（背景のみ） | 設定・Presets |
| `jChordSheetOuterBorder()` | — | **iPad のみ**・外周・`ignoresSafeArea` | ナビバー（Cancel 等）より外側 |
| `jChordPopupPanelChrome(cornerRadius:)` | `popupPanel` + 影 | **全端末** | Input Notes フローティング |
| `presentationCornerRadius(18)` | — | — | 設定・Presets・購入の `.sheet` |

### 端末別の外周白枠（`JChordDeviceTraits.showsPopupSheetOuterBorder`）

| 端末 | 外周白枠 |
|------|----------|
| **iPhone**（6.5" MAX 含む） | **付けない**（フルブリードシートで物理角に枠が切れるため） |
| **iPad**（mini 以上） | **付ける**（`userInterfaceIdiom == .pad`） |

短辺 pt の目安: iPhone MAX 縦 430 / iPad mini 縦 **744**（mini の方が広い）。

### 画面ごとの適用（現行）

| 画面 | 背景 | 外周白枠（iPad） | 角丸 |
|------|------|------------------|------|
| **設定**（`MidiSettingsView`） | `popupPanel` | `jChordSheetOuterBorder` | 18 |
| **Presets**（`PresetPickerView`） | `popupPanel`（外枠・フッター・＋行）。リスト行は `panel` | 同上 | 18 |
| **購入**（`ProUpgradeSheet`） | `jChordScreenBackground()`（グラデーション） | 同上 | 18 |
| **Input Notes**（オーバーレイ） | `jChordPopupPanelChrome(18)` | 全端末で面板に白枠 | — |
| オーバーレイ背面 | 黒 45% | — | — |

設定の内側カード（PAD OUT / KEYBOARD IN 等）は `JChordTheme.panel` + 白 8% 枠（`MidiRoutingSettingsContent.settingsCard`）。

購入シートは iOS 26 でツールバーのガラス背景を非表示（`jChordToolbarNoGlassBackground`）し、Cancel を外枠の内側に揃える。

## メイン画面

- 背景: `jChordScreenBackground()`
- パッド: アイドル灰グラデーション / 発音オレンジ / 押下時の減光
- 上部: セット名・MIDI OUT 状態ドット・設定（歯車）
- 下部: Velocity / Expression スライダー（**セット横断で共通**、`MidiPerformanceSettings` / `@AppStorage`）
- セット巡回: `<` `>`（`rotationSlotsInOrder` が 2 件以上のとき有効）
- Input Notes: 半透明オーバーレイ上にフローティング POPUP（幅 `min(500, max(280, …))`）

## ビルド識別（Settings フッター）

`AppBuildIdentity.settingsFooterLine` 例:

```text
JPad 1.0.02 (108) · sheet-chrome-v1
```

| 項目 | 管理場所 |
|------|----------|
| Marketing | `project.yml` → `MARKETING_VERSION`（現行 `1.0.02`） |
| Build | `CURRENT_PROJECT_VERSION`（TestFlight 毎に +1、現行 **108**） |
| `layoutRevision` | `AppBuildIdentity.swift`（UI 世代の目視確認用） |

## 関連コード

| 用途 | パス |
|------|------|
| テーマ・modifier | `JPad/Shared/Design/JChordTheme.swift` |
| 設定シート | `JPad/Features/MidiRouting/MidiSettingsView.swift` |
| Presets シート | `JPad/Features/Main/PresetPickerView.swift` |
| 購入シート | `JPad/Features/Main/ProUpgradeSheet.swift` |
| Input Notes | `JPad/Features/PadEditor/PadInputNotesEditorSheet.swift` |
| シート present | `JPad/Features/Main/MainView.swift` |

機能仕様（プリセット・Pro・jcstore）は [PRESET_LIBRARY.md](PRESET_LIBRARY.md) を参照。
