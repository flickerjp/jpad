# RIFF / SEQ モード追加 要件

TinyTone(JPad) のパッド操作モードに、既存の Slider / Transpose に加えて RIFF(リフ)と SEQ(ステップシーケンサー)の 2 モードを追加するための要件。**初版は実装済み**(2026-06-10。下記「実装メモ」参照)。

> **名称変更(2026-06-11)**: 当初 ARP(アルペジエーター)と呼んでいたが、機能的にはリフ(短い反復フレーズ)であるため、**ラベル・内部コードとも RIFF に統一**した。`PresetPadControlMode` の旧 `arp` 値・`sequencerSettings.arp` キーは decode 時に `riff` へマップして後方互換を保つ。本書中の旧記述「ON / OFF トグル」は、後の変更で**スロット 1〜4 を押すと直接トグル(オン/オフ)する方式**に変更済み(専用 ON ボタンは廃止)。SEQ も同様にスロット押下で直接ラッチ再生する。

## 目的

- パッドにアサインされたコードを、カスタマイズ可能なリフパターンで自動演奏する `RIFF` モードを追加する
- SH-101 ライクな 16 ステップのパターンシーケンサー `SEQ` モードを追加する
- モードが 4 つに増えるため、モード選択 UI のラベルを短縮してスペースを確保する

## 用語

| 用語 | 意味 |
|------|------|
| セット | `Preset`(ユーザーセット)。RIFF/SEQ の設定はセット単位で保存する |
| パターン | RIFF のステップ譜面、または SEQ のステップ列 1 本ぶん |
| ステップ | 16 分音符 1 個ぶんのタイミング枠 |
| MIDI Clock 追従 | 外部 MIDI Clock(24 ppqn)の受信でテンポを得るモード |
| U / M1 / M2 / L | RIFF でコード構成音を音域でグルーピングした Upper / Middle 1 / Middle 2 / Lower の 4 声部 |

## モード共通

### モード選択 UI

- パッド操作モードは `SLD` / `TRSP` / `RIFF` / `SEQ` の 4 択にする
- 既存ラベルを短縮する
  - `SLIDER` → `SLD`
  - `TRANSPOSE` → `TRSP`
- モード選択 UI は **縦表示のときのみ** 表示する(現行仕様を継続)
- RIFF / SEQ の**パターンスロット 1〜4 の選択は横表示でも可能**にする(モード切替は縦のみ、スロット切替は縦横どちらでも)
- 実装上は `PresetPadControlMode`(`JPad/Models/Preset.swift`)に `riff` / `seq` を追加し、decode 失敗時は従来どおり `.sliders` へフォールバックして後方互換を保つ

### テンポと同期

- テンポソースは 2 択。**設定画面**で指定する
  - 内部テンポ: セットごとに BPM を指定(RIFF / SEQ 設定画面から変更できる)
  - 外部同期: **MIDI Clock(24 ppqn)の受信**に追従する
- RIFF と SEQ は同じテンポソース設定を共有する
- 現状 MIDI は送信のみ(`MidiOutputService`)。外部同期には **MIDI 入力(受信)基盤の新設**が必要
- 補足: 当初要件では「MTC」としていたが、MTC は絶対時刻の伝送でテンポ(BPM)を含まないため、外部同期は MIDI Clock 追従で確定(2026-06-10)

### 内部テンポの仕様

- BPM 範囲: 40〜240(案)
- ステップ分解能: 16 分音符固定

## RIFF(リフ)モード

### コンセプト

UP / DOWN などの既成パターンを選ぶ方式ではなく、**ユーザー自身がリフパターンを組める**方式にする。パッドを押している間、そのパッドのコードがパターンに従って自動演奏される。

### パターン構成

- TR-808 のステップ指定のように、**16 ステップ × 4 声部(U / M1 / M2 / L)** のグリッドで発音タイミングを指定する

```text
U   x x x o x x x o o o x o o o o o
M1  o x o x x o o o o o x o o o o o
M2  x o x o o x x o x o o x o o o o
L   o o x x o x x x o o x o o o o o
```

- `o` = 発音、`x` = 休み
- 各ステップは複数声部の同時発音を許す(例: 同ステップで U と L が `o`)
- RIFF エディタ左下の `TIE` を有効にした状態で、同一声部の連続した発音ステップを横スワイプすると、後続ステップは再発音せず直前の音を伸ばす

### 声部グルーピング(U / M1 / M2 / L)

- セットごとに **基準キー(ノート)** を 1 つ定義する
- 基準キーより上のレンジにあるコード構成音を RIFF の対象とする
- **基準キーより下の構成音は鳴らさない**
- 構成音が 4 音のときは、高い順に U / M1 / M2 / L へ 1 音ずつ割り当てる
- 構成音が 3 音のときは、高い順に U / M1 / L へ割り当て、M2 は空にする
- 構成音が 5 音以上のときは、最高音を U、最低音を L に固定し、中間音を近い音域どうしで M1 / M2 に分ける

### パターン数

- セットごとに **4 つのリフ(パターンスロット)** を作成できる
- 演奏時はそのうち 1 つを選択して使う(Transpose の 4 メモリー `PresetShiftMemory` と同じ操作モデル)
- 基準キーの定義はセットごとに 1 つで、4 スロットで共有する

### RIFF 設定画面

- 設定スペースが少ないため、**パッド 1〜8 のエリアも設定画面として使用**する
- 設定項目
  - テンポ(BPM。テンポソースが内部のときのみ有効)
  - 16 × 4 ステップグリッドの編集
  - パターンスロット 1〜4 の選択
  - 基準キーの指定
  - **デュレーションを決めるスライダー**(各発音のゲート長。ステップ長に対する割合)

### 演奏時 UI

- 演奏画面では **ON / OFF のトグルのみ**(パッドを押すと ON のときだけリフ演奏、OFF のときは通常発音)

## SEQ(ステップシーケンサー)モード

### コンセプト

SH-101 のようなステップ入力式パターンシーケンサー。ステップを 1 つずつ入力してパターンを作り、再生するとパッド(コード)が順に発音される。

### 仕様

- **16 ステップ**、1 ステップ = 16 分音符
- 入力方法(SH-101 方式)
  - パッドを 1 つずつ選んでステップに記録する
  - `TIE`: 直前の音を伸ばす(16 分音符 → 8 分音符。連続入力でさらに延長)
  - `REST`: 休符を入れる
- 入力ステップ数が 16 未満のときでも **16 分音符ぶんの長さで演奏**する(入力した長さでループし、各ステップを引き伸ばさない)
- 再生は先頭からのループ再生

### パターン数

- セットごとに **4 パターン** を指定できる
- テンポ指定・MIDI Clock 追従は RIFF と同様(共通のテンポソース設定に従う)

### SEQ 設定画面

- 設定項目(案)
  - テンポ(BPM。内部テンポ時のみ)
  - パターンスロット 1〜4 の選択
  - ステップ入力(パッド選択 / TIE / REST / クリア)
- RIFF 同様、必要に応じてパッドエリアを設定 UI に転用してよい

### 演奏時 UI

- 再生 / 停止のトグル(案)
- 再生中の現在ステップ表示があると望ましい(案)

## データモデルへの影響

- `PresetPadControlMode` に `riff` / `seq` を追加
- `PresetControlSettings`(または並列の新設定構造体)に以下を追加
  - テンポソース(internal / external)と BPM
  - RIFF: パターンスロット ×4(16×4 グリッド、デュレーション)、基準キー、選択スロット index
    - RIFF の TIE は `ties[voice][step]` として保存する。旧データに `ties` が無い場合は全ステップ非 TIE
  - SEQ: パターンスロット ×4(ステップ列: パッド index / TIE / REST)、選択スロット index
- Codable は `decodeIfPresent` + デフォルト値で**古い `.jpd` / `.json` / `.jchord` import を壊さない**(`docs/DATA_FORMATS.md` の方針に従う)
- RIFF / SEQ 設定は `.jpd` export に含め、共有時に再現できるようにする

## 確定事項(2026-06-10)

- パターンスロットは RIFF / SEQ ともセットごとに **4 つ**。基準キー定義はセットごとに 1 つ(全スロット共有)
- SEQ で 16 ステップ未満のときは、入力した長さでループする(各ステップは 16 分のまま)
- 外部同期は **MIDI Clock(24 ppqn)追従**(当初要件の「MTC」から変更)
- RIFF の **基準キーより下の構成音は鳴らさない**
- Transpose の短縮ラベルは **`TRSP`**
- **横表示でも RIFF / SEQ のスロット選択は可能**(モード切替自体は縦表示のみ)

残る詳細(BPM 範囲、3 音以下時の声部割り当て、SEQ 演奏時 UI など)は本文中に (案) として記載。実装時に確定する。

## 実装メモ(2026-06-10 初版)

| 対象 | パス |
|------|------|
| RIFF/SEQ データモデル(`PresetSequencerSettings` ほか) | `JPad/Models/PadSequencerSettings.swift` |
| `PresetPadControlMode` の `riff` / `seq`、`Preset.sequencerSettings` | `JPad/Models/Preset.swift`, `Preset+Codable.swift`, `Preset+Editing.swift` |
| ステップクロック・声部グルーピング・SEQ 解決 | `JPad/Services/Sequencer/PadSequencerEngine.swift` |
| MIDI Clock (24 ppqn) 受信・BPM 推定 | `JPad/Services/Midi/MidiClockReceiver.swift` |
| RIFF/SEQ コントロール UI・RIFF パターンエディタ | `JPad/Features/Main/MainRiffSeqControls.swift` |
| モード 4 択・パッド押下ルーティング | `JPad/Features/Main/MainView.swift`, `MainViewModel.swift` |
| テンポ源切替(設定画面 CLOCK セクション) | `JPad/Features/MidiRouting/MidiRoutingSettingsContent.swift`, `MidiSettingsView.swift` |
| ラベル文言(`main.controls.*`, `main.riff.*`, `main.seq.*`, `settings.clock_source.*`) | `JPad/Resources/en.lproj/Localizable.strings`, `ja.lproj/Localizable.strings` |

実装上の決定事項:

- 発音は `MidiOutputService` の preview note API(`sendPreviewNoteOn/Off`、ref count 管理)経由。PAD OUT ルーティング(内蔵 TinyTone / 外部 MIDI)にそのまま乗る
- RIFF の ON/OFF・SEQ の REC 状態はランタイムのみ(セットへ保存しない)。パターン・BPM・基準キー・ゲートはセットに保存し `.jpd` export にも含まれる
- RIFF パターンエディタは全面オーバーレイ(パッド 1〜8 エリアを含む画面全体を使用)
- RIFF TIE は発音開始ステップのゲート長を後続 TIE ステップ分だけ伸ばし、TIE ステップ側の Note On は出さない
- RIFF / SEQ の同時発音ノートは低い音から送る
- テンポ源(INTERNAL / MIDI CLOCK)はアプリ全体設定(`AppStorage`)。MIDI Clock 未受信時は内部 BPM にフォールバック
- 旧 preset(`sequencerSettings` なし)はデフォルト値で decode。未知の `padControlMode` 値は `sliders` にフォールバック(検証済み)
