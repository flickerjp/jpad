# AGENTS.md

Codex、Gemma、Ollama、Aider などの coding agent がこのリポジトリで作業するときの共通ルール。
この文書は RAG 用メモではなく、作業開始時に必ず読む公式説明書として扱う。

## 最初に読む順番

1. `docs/AGENTS.md`
2. `docs/ARCHITECTURE.md`
3. `docs/DATA_FORMATS.md`
4. `docs/TASKS.md`
5. 変更対象に近い既存コード

関連がある場合は次も読む。

- UI: `docs/UI_DESIGN.md`, `docs/UI_REFRESH_TINYTONE_DIRECTION.md`
- プリセット保存: `docs/PRESET_LIBRARY.md`, `docs/PRESET_STORAGE.md`
- TinyTone 内蔵音源: `docs/TINYTONE_AUDIO.md`
- TinyTone App Group 共有: `docs/TINYTONE_APP_GROUP_SHARING.md`
- 引き継ぎ: `docs/HANDOVER.md`

## 基本方針

- まず既存コードと既存ドキュメントを確認する。
- 仕様が読めるなら、推測で作らず実体に合わせる。
- 変更は最小差分で入れる。
- 互換性を壊す変更は避ける。壊す必要があるなら移行手順を先に書く。
- UI、保存、MIDI、課金、共有の責務を混ぜない。
- RAG の検索結果だけで実装判断しない。最後は必ず実ファイルを読む。

## 調査ルール

- 先に `rg` で対象シンボルを探し、対象ファイルを読む。
- 既存の命名、構造、保存形式、UI の流儀を優先する。
- 影響範囲が広い変更は、実装前に関連箇所を横断して確認する。
- 仕様が不明なときは、コードと既存文書の両方を根拠にする。
- Swift/iOS の作業では、型名、import、AppStorage key、保存 path、Bundle ID、entitlement を推測で変えない。
- `project.yml` が Xcode project 生成の正本。`JPad.xcodeproj` だけを手で直さない。

よく使う探索コマンド:

```bash
rg -n "MainViewModel|MidiOutputService|UserPresetLibrary|PresetImportExportService|ProPurchaseService" JPad docs
rg -n "TinyTone|App Group|SharedPatch|previewSound" JPad docs
rg -n "MARKETING_VERSION|CURRENT_PROJECT_VERSION|PRODUCT_BUNDLE_IDENTIFIER" project.yml JPad.xcodeproj/project.pbxproj
```

## 実装ルール

- 勝手に大改造しない。
- 既存の入出力や保存データの互換性を保つ。
- 既存の JSON、App Group、課金、MIDI の経路を安易に置き換えない。
- ふるまいを変える場合は、同じ入力で何が変わるかを明示する。
- 取り消しや復元が必要な操作は、先に安全な経路を作る。
- 既存の `LOAD` / `EXPORT` / 手動 JSON 取り込みの経路を App Group 共有で置き換えない。
- 課金の見た目だけを変えず、保存・共有・複製などの実処理 gate と矛盾させない。
- UI 変更では TinyTone 寄せの見た目を意識しつつ、PAD の idle は灰色、tap/active emphasis は orange を基本にする。

## 変更前後の確認

- 実装したら、関連ファイルを再読して差分が仕様に沿うか確認する。
- 可能なら実機または起動確認まで行う。
- 共有データ、保存数、課金境界は特に慎重に確認する。
- 生成物を変えた場合は、正本と生成物の両方を確認する。

標準確認コマンド:

```bash
make project
xcodebuild -project JPad.xcodeproj -scheme JPad -configuration Debug -destination 'generic/platform=iOS Simulator' build
git diff -- docs/AGENTS.md docs/ARCHITECTURE.md docs/DATA_FORMATS.md docs/TASKS.md project.yml JPad.xcodeproj/project.pbxproj
```

## RAG / Ollama / Gemma との分業

- RAG、Ollama、Gemma は下調べ、要約、候補出しに使える。
- 最終判断は、このリポジトリの既存実装と文書を優先する。
- 提案が既存仕様とズレる場合は、そのまま採用しない。

RAG に入れてよいもの:

- `README.md`
- `docs/AGENTS.md`
- `docs/ARCHITECTURE.md`
- `docs/DATA_FORMATS.md`
- `docs/TASKS.md`
- 仕様メモ、設計メモ、主要 Swift ファイルの要約

RAG だけに頼らないもの:

- 最新の Swift 実装
- Xcode build error
- `project.yml` / generated project の差分
- entitlement、Bundle ID、StoreKit product ID
- 保存形式の decode / encode 実装
