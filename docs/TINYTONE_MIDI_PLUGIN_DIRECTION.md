# TinyTone MIDI / Plugin 化 方針

目的: TinyTone を JPad に負荷をかけず、単体の無料機能として MIDI 対応・プラグイン対応する方向を整理する。JPad は TinyTone 音色ライブラリを読むだけに留め、MIDI routing / AUv3 host / plugin UI の責務を持たせない。

## 結論

- GarageBand 対応は **入口として筋が良い**。iPhone ユーザーに説明しやすく、Apple 純正で導入済みの可能性が高い。
- ただし GarageBand 専用設計にはしない。TinyTone は **AUv3 Instrument** と **standalone MIDI input** を標準的に実装する。
- MIDI 化・プラグイン化は **無料機能** として扱う。TinyTone Pro の価値は保存ライブラリ 5 件超、将来の高度機能に寄せる。
- JPad は plugin host にならない。JPad 側の負荷を増やさない。

## 機能境界

| アプリ | やること | やらないこと |
|--------|----------|--------------|
| TinyTone | MIDI input、AUv3 Instrument、GarageBand/AUM/Loopy/Cubasis 等で鳴る音源 | JPad の画面・MIDI負荷に依存する実装 |
| JPad | App Group の TinyTone 音色を読む。内蔵 PAD OUT として鳴らす | AUv3 host、外部DAW制御、plugin管理 |

TinyTone 側は `TinyToneCore` を使う audio engine / patch model の正本。JPad 側は既存の `TinyToneEngine` 経由で鳴らすだけにする。

## GarageBand を対象にする妥当性

GarageBand は iPhone で Audio Unit Extensions / Inter-App Audio app を instrument / effect として使えるため、TinyTone を AUv3 Instrument として出す価値はある。

ただし GarageBand は本格的な MIDI routing / AUv3 MIDI processor host としての自由度は高くない。ターゲットとしては「初心者が TinyTone を録音する入口」と位置付ける。

向いている使い方:

- GarageBand の Audio Unit Instrument として TinyTone を挿す。
- GarageBand 上で TinyTone の音を演奏・録音する。
- TinyTone の音色を App Group ライブラリで管理し、プラグイン側でも選ぶ。

避ける前提:

- GarageBand 専用の独自 workaround を増やす。
- JPad を GarageBand のための MIDI bridge にする。
- GarageBand の制約を補うために JPad 側へ routing 機能を持たせる。

## 他の iPhone ターゲット

| 優先 | アプリ | 理由 |
|------|--------|------|
| 高 | GarageBand for iPhone | 無料・Apple純正・説明しやすい。AUv3 instrument の入口として強い |
| 高 | AUM | AUv3 host / MIDI routing の定番。Instrument / Music Effect が host から直接 MIDI を受けられる |
| 高 | Loopy Pro | iPhone/iPad 対応。AUv3 plugins、MIDI routing、live performance の用途に合う |
| 中 | Cubasis 3 | iPhone対応のDAW。AUv3 / IAA / Audiobus / MIDI hardware 対応があり、録音用途に向く |
| 中 | Audiobus | app / AUv3 間の audio/MIDI routing 検証に使いやすい |
| 低-要確認 | KORG Gadget 3 | iPhone対応・外部MIDI対応はあるが、TinyTone AUv3 host としての使い方は要検証 |

Logic Pro for iPad は有力な AUv3 host だが、iPhone アプリではないため今回の主対象から外す。iPad 展開時の確認先として扱う。

## 実装形

### 1. Standalone MIDI input

TinyTone アプリ本体が CoreMIDI / Bluetooth MIDI / connected MIDI controller を受ける。

- 無料機能。
- TinyTone 単体で外部 MIDI keyboard から演奏できる。
- GarageBand とは別に、AUM / Audiobus / hardware controller 検証にも使える。

### 2. AUv3 Instrument

TinyTone を AUv3 Instrument として提供する。

- 無料機能。
- Host は GarageBand / AUM / Loopy Pro / Cubasis など。
- Engine は `TinyToneCore` を使う。
- App Group library を読み、保存済み音色を plugin UI から選べるようにする。
- 未保存 draft は plugin では扱わず、保存済み音色だけを対象にする。

### 3. AUv3 MIDI Processor は後回し

TinyTone 自体は音源なので、初期は Instrument を優先する。MIDI Processor は JPad 的な chord/pad MIDI 生成に寄りやすく、JPad の責務と混ざるため後回し。

## 無料/有料の切り分け

| 機能 | 価格方針 |
|------|----------|
| Standalone MIDI input | 無料 |
| AUv3 Instrument | 無料 |
| GarageBand / AUM / Loopy / Cubasis で鳴らす | 無料 |
| App Group library 5 件まで | 無料 |
| App Group library 5 件超 | TinyTone Pro 候補 |
| 将来の高度機能 | TinyTone Pro 候補 |

JPad Pro とは連動させない。TinyTone で無料提供する MIDI / plugin 機能は、JPad の課金導線に載せない。

## UI 方針

TinyTone:

- `MIDI` セクションを追加し、入力元・Bluetooth MIDI・チャンネルを設定できるようにする。
- `Plugin` セクションは説明中心にし、GarageBand / AUM / Loopy / Cubasis で使えることを簡潔に案内する。
- App Group library の音色一覧を plugin と standalone で共有する。

JPad:

- UI 追加は最小限。`From TinyTone` の音色一覧を読むだけ。
- GarageBand / plugin / MIDI routing の説明や設定を JPad 内に持ち込まない。

## 検証順

1. TinyTone standalone で外部 MIDI keyboard / Bluetooth MIDI 入力を受ける。
2. AUv3 Instrument として最小音源を host に表示する。
3. GarageBand for iPhone で instrument として読み込めるか確認する。
4. AUM / Loopy Pro / Cubasis で MIDI input、preset selection、audio stability を確認する。
5. App Group library の音色選択を AUv3 plugin UI から読めるようにする。

## 関連ドキュメント

- [TINYTONE_APP_GROUP_SHARING.md](TINYTONE_APP_GROUP_SHARING.md) — App Group 保存ライブラリ、JPad 連携、無料/Pro 切り分け
- [TINYTONE_AUDIO.md](TINYTONE_AUDIO.md) — JPad 内蔵 TinyTone 経路
