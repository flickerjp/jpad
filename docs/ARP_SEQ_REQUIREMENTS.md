# ARP / SEQ モード追加 要件

TinyTone(JPad) のパッド操作モードに、既存の Slider / Transpose に加えて ARP(アルペジエーター)と SEQ(ステップシーケンサー)の 2 モードを追加するための要件。**初版は実装済み**(2026-06-10。下記「実装メモ」参照)。

## 目的

- パッドにアサインされたコードを、カスタマイズ可能なアルペジオパターンで自動演奏する `ARP` モードを追加する
- SH-101 ライクな 16 ステップのパターンシーケンサー `SEQ` モードを追加する
- モードが 4 つに増えるため、モード選択 UI のラベルを短縮してスペースを確保する

## 用語

| 用語 | 意味 |
|------|------|
| セット | `Preset`(ユーザーセット)。ARP/SEQ の設定はセット単位で保存する |
| パターン | ARP のステップ譜面、または SEQ のステップ列 1 本ぶん |
| ステップ | 16 分音符 1 個ぶんのタイミング枠 |
| MIDI Clock 追従 | 外部 MIDI Clock(24 ppqn)の受信でテンポを得るモード |
| U / M / L | ARP でコード構成音を音域でグルーピングした Upper / Middle / Lower の 3 声部 |

## モード共通

### モード選択 UI

- パッド操作モードは `SLD` / `TRSP` / `ARP` / `SEQ` の 4 択にする
- 既存ラベルを短縮する
  - `SLIDER` → `SLD`
  - `TRANSPOSE` → `TRSP`
- モード選択 UI は **縦表示のときのみ** 表示する(現行仕様を継続)
- ARP / SEQ の**パターンスロット 1〜4 の選択は横表示でも可能**にする(モード切替は縦のみ、スロット切替は縦横どちらでも)
- 実装上は `PresetPadControlMode`(`JPad/Models/Preset.swift`)に `arp` / `seq` を追加し、decode 失敗時は従来どおり `.sliders` へフォールバックして後方互換を保つ

### テンポと同期

- テンポソースは 2 択。**設定画面**で指定する
  - 内部テンポ: セットごとに BPM を指定(ARP / SEQ 設定画面から変更できる)
  - 外部同期: **MIDI Clock(24 ppqn)の受信**に追従する
- ARP と SEQ は同じテンポソース設定を共有する
- 現状 MIDI は送信のみ(`MidiOutputService`)。外部同期には **MIDI 入力(受信)基盤の新設**が必要
- 補足: 当初要件では「MTC」としていたが、MTC は絶対時刻の伝送でテンポ(BPM)を含まないため、外部同期は MIDI Clock 追従で確定(2026-06-10)

### 内部テンポの仕様

- BPM 範囲: 40〜240(案)
- ステップ分解能: 16 分音符固定

## ARP(アルペジエーター)モード

### コンセプト

UP / DOWN などの既成パターンを選ぶ方式ではなく、**ユーザー自身がアルペジオパターンを組める**方式にする。パッドを押している間、そのパッドのコードがパターンに従って自動演奏される。

### パターン構成

- TR-808 のステップ指定のように、**16 ステップ × 3 声部(U / M / L)** のグリッドで発音タイミングを指定する

```text
U  x x x o x x x o o o x o o o o o
M  o x o x x o o o o o x o o o o o
L  o o x x o x x x o o x o o o o o
```

- `o` = 発音、`x` = 休み
- 各ステップは複数声部の同時発音を許す(例: 同ステップで U と L が `o`)

### 声部グルーピング(U / M / L)

- セットごとに **基準キー(ノート)** を 1 つ定義する
- 基準キーより上のレンジにあるコード構成音を ARP の対象とする
- **基準キーより下の構成音は鳴らさない**
- 構成音が 4 音以上のときは、**近い音域どうしでグルーピング**して U / M / L の 3 声部に割り当てる
- 3 音以下のときは高い順に U / M / L へ 1 音ずつ割り当てる(案)

### パターン数

- セットごとに **4 つのアルペジエーター(パターンスロット)** を作成できる
- 演奏時はそのうち 1 つを選択して使う(Transpose の 4 メモリー `PresetShiftMemory` と同じ操作モデル)
- 基準キーの定義はセットごとに 1 つで、4 スロットで共有する

### ARP 設定画面

- 設定スペースが少ないため、**パッド 1〜8 のエリアも設定画面として使用**する
- 設定項目
  - テンポ(BPM。テンポソースが内部のときのみ有効)
  - 16 × 3 ステップグリッドの編集
  - パターンスロット 1〜4 の選択
  - 基準キーの指定
  - **デュレーションを決めるスライダー**(各発音のゲート長。ステップ長に対する割合)

### 演奏時 UI

- 演奏画面では **ON / OFF のトグルのみ**(パッドを押すと ON のときだけアルペジオ演奏、OFF のときは通常発音)

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
- テンポ指定・MIDI Clock 追従は ARP と同様(共通のテンポソース設定に従う)

### SEQ 設定画面

- 設定項目(案)
  - テンポ(BPM。内部テンポ時のみ)
  - パターンスロット 1〜4 の選択
  - ステップ入力(パッド選択 / TIE / REST / クリア)
- ARP 同様、必要に応じてパッドエリアを設定 UI に転用してよい

### 演奏時 UI

- 再生 / 停止のトグル(案)
- 再生中の現在ステップ表示があると望ましい(案)

## データモデルへの影響

- `PresetPadControlMode` に `arp` / `seq` を追加
- `PresetControlSettings`(または並列の新設定構造体)に以下を追加
  - テンポソース(internal / external)と BPM
  - ARP: パターンスロット ×4(16×3 グリッド、デュレーション)、基準キー、選択スロット index
  - SEQ: パターンスロット ×4(ステップ列: パッド index / TIE / REST)、選択スロット index
- Codable は `decodeIfPresent` + デフォルト値で**古い `.jpd` / `.json` / `.jchord` import を壊さない**(`docs/DATA_FORMATS.md` の方針に従う)
- ARP / SEQ 設定は `.jpd` export に含め、共有時に再現できるようにする

## 確定事項(2026-06-10)

- パターンスロットは ARP / SEQ ともセットごとに **4 つ**。基準キー定義はセットごとに 1 つ(全スロット共有)
- SEQ で 16 ステップ未満のときは、入力した長さでループする(各ステップは 16 分のまま)
- 外部同期は **MIDI Clock(24 ppqn)追従**(当初要件の「MTC」から変更)
- ARP の **基準キーより下の構成音は鳴らさない**
- Transpose の短縮ラベルは **`TRSP`**
- **横表示でも ARP / SEQ のスロット選択は可能**(モード切替自体は縦表示のみ)

残る詳細(BPM 範囲、3 音以下時の声部割り当て、SEQ 演奏時 UI など)は本文中に (案) として記載。実装時に確定する。

## 実装メモ(2026-06-10 初版)

| 対象 | パス |
|------|------|
| ARP/SEQ データモデル(`PresetSequencerSettings` ほか) | `JPad/Models/PadSequencerSettings.swift` |
| `PresetPadControlMode` の `arp` / `seq`、`Preset.sequencerSettings` | `JPad/Models/Preset.swift`, `Preset+Codable.swift`, `Preset+Editing.swift` |
| ステップクロック・声部グルーピング・SEQ 解決 | `JPad/Services/Sequencer/PadSequencerEngine.swift` |
| MIDI Clock (24 ppqn) 受信・BPM 推定 | `JPad/Services/Midi/MidiClockReceiver.swift` |
| ARP/SEQ コントロール UI・ARP パターンエディタ | `JPad/Features/Main/MainArpSeqControls.swift` |
| モード 4 択・パッド押下ルーティング | `JPad/Features/Main/MainView.swift`, `MainViewModel.swift` |
| テンポ源切替(設定画面 CLOCK セクション) | `JPad/Features/MidiRouting/MidiRoutingSettingsContent.swift`, `MidiSettingsView.swift` |
| ラベル文言(`main.controls.*`, `main.arp.*`, `main.seq.*`, `settings.clock_source.*`) | `JPad/Resources/en.lproj/Localizable.strings`, `ja.lproj/Localizable.strings` |

実装上の決定事項:

- 発音は `MidiOutputService` の preview note API(`sendPreviewNoteOn/Off`、ref count 管理)経由。PAD OUT ルーティング(内蔵 TinyTone / 外部 MIDI)にそのまま乗る
- ARP の ON/OFF・SEQ の REC 状態はランタイムのみ(セットへ保存しない)。パターン・BPM・基準キー・ゲートはセットに保存し `.jpd` export にも含まれる
- ARP パターンエディタは全面オーバーレイ(パッド 1〜8 エリアを含む画面全体を使用)
- テンポ源(INTERNAL / MIDI CLOCK)はアプリ全体設定(`AppStorage`)。MIDI Clock 未受信時は内部 BPM にフォールバック
- 旧 preset(`sequencerSettings` なし)はデフォルト値で decode。未知の `padControlMode` 値は `sliders` にフォールバック(検証済み)
