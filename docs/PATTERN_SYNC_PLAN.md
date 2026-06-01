# パターン同期・フレーズ記録案

これは **未実装の設計メモ**。JPad を「コード進行スケッチ」だけでなく、「テンポ同期したフレーズ記録・再生」の土台にするための具体案をまとめる。

## 狙い

単なる音の再生ではなく、以下を扱えるようにする。

- 外部機器のテンポに追従する
- パッド操作をタイムライン付きで記録する
- 記録した短いフレーズをパッドに割り当てる
- 必要なら SMF に書き出す

想定例:

- Roland P-6 でリズムを再生する
- P-6 から MIDI Clock / Start / Stop を JPad に送る
- JPad はそのテンポに合わせてパッド演奏を記録する
- JPad から GarageBand へ MIDI を送り、音色を鳴らしながらフレーズを残す
- 記録したフレーズを別パッドに割り当て、Ableton Live の clip launcher のように再生する

## 使い方の中心

この機能の主役は「録音」よりも「フレーズ化」。

- 1 パッド = 1 フレーズ
- フレーズは小節単位でループ可能
- パッドを押すと、そのフレーズを次の区切りで起動
- 同じフレーズを別のパッドへ複製できる
- フレーズはテンポ同期して再生される

音声録音ではなく、**MIDI イベントの記録**に寄せる。

## 受ける同期情報

P-6 のような外部機器から、最低限次を受けたい。

- `Clock`
- `Start`
- `Stop`
- `Continue`
- 可能なら `Song Position Pointer`

P-6 側は MIDI Clock Sync を持ち、USB / MIDI IN でクロックを受ける想定がある。JPad 側はまず「クロックの受信と内部 BPM への反映」を優先する。

## JPad 側の状態

JPad に必要な状態は次の 3 層に分ける。

### 1. Transport

- `tempo`
- `isPlaying`
- `positionInTicks`
- `bar`
- `beat`
- `tick`

### 2. Record

- `recordArmed`
- `recordQuantize`
- `recordTargetPadID`
- `recordStartPosition`
- `recordEndPosition`

### 3. Phrase

- `events`
- `lengthInBars`
- `loopEnabled`
- `assignmentPadID`
- `transposeMode`

## 記録するイベント

最初は MIDI ノートイベントだけでよい。

- `noteOn`
- `noteOff`
- `velocity`
- `timestampTicks`
- `sourcePadID`
- `transposeKey`
- `transposeOct`
- `holdState`

必要なら後から以下を足す。

- `controlChange`
- `programChange`
- `aftertouch`
- `sustain`

## フレーズの粒度

最初から自由長にすると扱いにくいので、段階を分ける。

### Phase 1

- 1 フレーズ = 1 小節
- 4/4 前提
- quantize は 1/16
- パッドごとのループ再生

### Phase 2

- 2 小節 / 4 小節を選べる
- 各フレーズの長さを可変にする
- 小節頭で切り替える

### Phase 3

- 自由長
- タイムシグネチャ対応
- MIDI クリップの並列再生

## 再生モデル

Ableton Live 風にするなら、再生単位を「パッド」ではなく「クリップ」として扱う。

- 各パッドに 1 つのフレーズを割り当てる
- 再生中のフレーズはテンポに合わせてループする
- 次のフレーズは小節頭で切り替える
- 既存の PAD OUT 音源はそのまま使える

つまり、JPad は **MIDI クリップランチャー** として振る舞う。

## SMF 出力

書き出しは最終的に Standard MIDI File にする。

### 書けるもの

- 1 トラックのメロディフレーズ
- 1 トラックごとのパッド分離
- 再生可能な note on/off

### まず決めること

- Type 0 にするか Type 1 にするか
- 量子化後のイベント時刻をどう並べるか
- テンポ情報を先頭に置くか
- ループ用のメタ情報をどう扱うか

### 実用案

- 内部保存は JPad 独自 JSON
- エクスポート時だけ SMF に変換
- クリップ単位で `.mid` を出せるようにする

## P-6 + GarageBand の使い方

想定ワークフローは次の形。

1. P-6 でリズムを再生する
2. P-6 のクロックを JPad が受ける
3. JPad のパッド演奏を記録する
4. JPad の MIDI OUT を GarageBand に向ける
5. GarageBand で音色を鳴らしながらフレーズを残す
6. 完成したフレーズを別パッドに割り当てる

この場合、P-6 はテンポマスター、JPad はフレーズ記録とクリップ再生、GarageBand は音源担当になる。

## 実装順

実装は次の順がよい。

1. MIDI Clock 受信
2. Transport 状態の導入
3. パッドイベント記録
4. 1 小節フレーズ再生
5. パッドへの割り当て
6. SMF エクスポート

## まだ決めなくてよいもの

- UI の最終見た目
- フレーズ一覧の画面構成
- 波形表示
- 録音の保存先
- 共有形式の最終拡張子

## 非対象

このメモでは次は扱わない。

- 音声録音
- 他アプリ音声のキャプチャ
- リアルタイムオーディオの書き出し
- 既存の `EXPORT / AIRDROP / IMPORT` の互換変更

