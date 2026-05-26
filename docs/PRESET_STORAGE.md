# プリセット・保存仕様（要約）

> **正本:** 機能・UI・JSON フローの詳細は [PRESET_LIBRARY.md](PRESET_LIBRARY.md)。  
> **UI:** [UI_DESIGN.md](UI_DESIGN.md)。  
> 旧ドキュメントにあった **My Stage / バンドル5枠固定 / LOAD・SAVE ボタン** モデルは **廃止**（2026-05 以降の JPad ライブラリ方式に置き換え済み）。

## 現行の画面構成（プリセット選択シート）

| 要素 | 説明 |
|------|------|
| タブ | **MY SETS** \| **STORE** |
| MY SETS | ユーザーライブラリ（最大 5 / 100 枠）。行タップでアクティブ化＋読み込み |
| STORE | jcstore カタログから取り込み |
| フッター | **SHARE** / **IMPORT** / 未購入時 **購入**（Pro 案内） |
| ツールバー | **ALL**（セット巡回）、**複製**（Pro）、タイトル + 枠数 |

LOAD / SAVE ボタンは **なし**。保存は **オートセーブ** のみ。

## 永続化（Application Support）

```
Application Support/JPad/library/user/
  index.json          … activePresetID, items[], hasCompletedInitialSeed
  presets/{uuid}.json … PresetSlotDocument（formatVersion 2）
```

次バージョン以降の検討: Pro だけ保存先を App Group に分けず、採用するなら Free / Pro 共通でライブラリ正本を App Group へ移す。詳細は [PRESET_LIBRARY.md](PRESET_LIBRARY.md) の「App Group 化の検討」。

| 操作 | 永続化 |
|------|--------|
| 編集・スロット切替・バックグラウンド | アクティブスロットへオートセーブ |
| 初回空ライブラリ | `PresetBundles/*.json` をシード（以降自動復元しない） |
| 削除 | スワイプ。0 件でも可。最後の1件削除後は再シードしない |
| Velocity / Expression | **プリセット外**（`UserDefaults` / `@AppStorage`、全セット共通） |

## エンタイトルメント（要約）

| | 無料 | Pro |
|---|------|-----|
| スロット | 5 | 100 |
| ＋空白 | ○ | ○ |
| 複製 | × | ○ |
| SHARE / IMPORT | × | ○ |
| jcstore 同時 | 1 件 | 無制限 |

## 初回オンボーディング

- 初回のみ `OnboardingView`（設定 UI 共有 + GarageBand 手順）
- 完了後 `jpad.onboardingCompleted`
- 設定の **HELP** から同内容を再表示可

## 実装状況（2026-05、ビルド 106 時点）

| 項目 | 状態 |
|------|------|
| マルチスロットライブラリ + オートセーブ | 実装 |
| jcstore manifest + 取り込み | 実装 |
| SHARE / IMPORT（`.jpd`） | 実装・UI 表示 |
| StoreKit 年額 Pro | 実装 |
| セット巡回 ALL / 行チェック | 実装 |
| グローバル Velocity / Expression | 実装 |

## 関連コード

| 用途 | パス |
|------|------|
| ライブラリ | `JPad/Services/PresetLoading/UserPresetLibrary.swift` |
| モデル | `JPad/Models/PresetLibraryModels.swift` |
| 共有 import/export | `JPad/Services/PresetLoading/PresetImportExportService.swift` |
| jcstore | `JPad/Services/Jcstore/JcstoreService.swift` |
| ピッカー UI | `JPad/Features/Main/PresetPickerView.swift` |
| 状態 | `JPad/Features/Main/MainViewModel.swift` |
| Pro 購入 | `JPad/Services/Store/ProPurchaseService.swift` |
