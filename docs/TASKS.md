# TASKS.md

今やりたい開発タスクのメモ。

この文書は「直近で着手するもの」と「中期候補」を分けて書く。
未実装案、RAG の思いつき、古い候補を全部ここに混ぜない。

## AI 作業開始時のチェック

- `docs/AGENTS.md` を読む。
- `docs/ARCHITECTURE.md` で責務境界を確認する。
- `docs/DATA_FORMATS.md` で保存・共有形式の互換性を確認する。
- この `docs/TASKS.md` と `docs/HANDOVER.md` の次回着手項目を突き合わせる。
- 実装前に `rg` で対象シンボルを探し、現行 Swift ファイルを読む。

## 直近

- 設定画面の実機確認
  - `PRESET` → `TT/GB` → `PAD OUT/MIDI IN` の並びを確認する
  - 選択済み `PAD OUT` の再タップで `TEST NOTE` が分かるか確認する
  - TinyTone 専用 `TEST NOTE` と再読み込みアイコンの使い勝手を確認する

- agent 用ドキュメント整備
  - `AGENTS.md` / `ARCHITECTURE.md` / `DATA_FORMATS.md` / `TASKS.md` を入口として使える状態に保つ
  - RAG に入れる情報と、実ファイル確認が必要な情報を分ける
  - コード変更後に文書が古くなった場合は同じ作業で更新する

## 次に着手しうるもの

- レイアウト可変化
  - 小さい画面と大きい画面で崩れないようにする
  - パネル幅、ボタン列、余白を固定値依存から減らす

- 横表示対応
  - iPhone 横向きで主要画面を破綻させない
  - 設定画面と編集画面の優先順位を整理する

- トランスポーズ強化
  - KEY / OCT の操作を分かりやすくする
  - 既存プリセットの transposeSettings と整合させる

- App Group 共有の安定化
  - TinyTone 共有 patch の読み取りを安定させる
  - 破損データや欠落ファイルの fallback を固める

- 保存まわりの整理
  - オートセーブの境界を明確にする
  - LOAD / SAVE 相当の見え方を必要最小限に保つ

## 将来案

- 横表示とパッドグリッド拡張
  - 詳細は `PAD_GRID_LAYOUT_REQUIREMENTS.md`
  - 4x4 モードや 4x3 横表示は未実装要件として扱う

- テンポ同期フレーズ機能
  - 詳細は `PATTERN_SYNC_PLAN.md`
  - まだ実装着手しない前提の設計メモ

## 直近で触るときの注意

- 仕様書を先に更新する。
- 保存形式を変えるなら移行手順を用意する。
- 共有や課金の境界を UI の都合だけで変えない。
- `HANDOVER.md` の次回着手項目と矛盾させない。
- `project.yml` を変えたら `make project` で生成物を更新する。
- `.jpd` / `.json` / `.jchord` 系 import 互換性を狭めない。
- TinyTone App Group 共有は既存の JSON LOAD / EXPORT の置き換えにしない。

## 優先順位の付け方

1. 壊れやすい部分を先に守る
2. UI の見た目よりデータの互換性を優先する
3. 次の実装が読みやすくなる順で片付ける

## 検証メモ

標準の静的確認:

```bash
rg -n "TODO|FIXME" docs JPad
rg -n "AGENTS|ARCHITECTURE|DATA_FORMATS|TASKS" .
git diff -- docs/AGENTS.md docs/ARCHITECTURE.md docs/DATA_FORMATS.md docs/TASKS.md AGENTS.md
```

コードや project 設定を変えた場合:

```bash
make project
xcodebuild -project JPad.xcodeproj -scheme JPad -configuration Debug -destination 'generic/platform=iOS Simulator' build
```
