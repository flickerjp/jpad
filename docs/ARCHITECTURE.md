# ARCHITECTURE.md

JPad 全体の構造メモ。実装の境界を確認するときの正本。

## 全体像

JPad は「パッド演奏」「MIDI 出力」「プリセット保存」「課金判定」「TinyTone 共有」を分けて持つ。

```mermaid
flowchart LR
  UI[SwiftUI UI] --> VM[MainViewModel]
  VM --> MIDI[MidiOutputService]
  VM --> SAVE[UserPresetLibrary]
  VM --> BILL[ProPurchaseService]
  VM --> TT[TinyTone engine / preview]
  VM --> SHARE[PresetImportExportService]
  MIDI --> APPGROUP[App Group shared patches]
  SAVE --> DISK[Local preset library]
  SHARE --> FILE[.jpd / import files]
```

## UI

- 画面の入口は `JPadApp` と `MainViewModel`。
- UI は状態を表示するだけに寄せる。
- 画面切り替えやモーダルの制御は ViewModel 側に集める。
- 編集 UI、設定 UI、購入 UI は別責務として扱う。

## MIDI

- `MidiOutputService` が MIDI 出力の中心。
- パッド発音、プレビュー、入力キャプチャはここを通す。
- UI は MIDI パケットを直接組み立てない。
- MIDI の接続状態、送信可否、プレビュー再生の初期化はサービス側で管理する。

## TinyTone

- TinyTone は JPad の内蔵音色・プレビュー音源として扱う。
- ここは UI とは別に、音色パラメータと再生準備を持つ。
- JPad の保存データと TinyTone の共有データは同一ではない。
- App Group を使う場合でも、TinyTone 共有は「追加経路」であり、既存 JSON 経路を消さない。
- 現行実装では App Group 共有 patch の読込窓口は `MidiOutputService` 側にあり、TinyTone エンジン自身が共有 index を読む構造ではない。

## 保存

- ユーザーセットの正本はローカル保存。
- 編集結果はオートセーブ前提。
- 既存の共有・書き出し形式は、ローカル保存とは別に扱う。
- 保存の責務は `UserPresetLibrary` と `PresetImportExportService` に分ける。

## 課金

- 課金状態は `ProPurchaseService` で判定する。
- 課金は保存件数、複製、共有、取り込み制御に影響する。
- 課金判定は UI 表示だけでなく、保存・共有の実処理にも反映する。

## App Group

- App Group は主に TinyTone 共有音色のための追加レイヤー。
- 共有データは `index.json` と個別 patch file に分ける。
- JPad は共有データを read-only で読む前提を基本にする。
- 現行コードでは `MidiOutputService` 内の共有ライブラリ reader が App Group を読み、選択した patch data を TinyTone プレビュー再生へ渡す。
- 保存済みローカルセットの正本を App Group 側に安易に移さない。

## 境界

- UI が保存形式を知りすぎない。
- MIDI が課金状態を直接判断しない。
- 保存が描画ロジックを持たない。
- 共有データがローカルセットの正本を上書きしない。
