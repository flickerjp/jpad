# DATA_FORMATS.md

JPad が扱う主要データ形式のメモ。
保存形式を変える前に、対象の encode / decode 実装を必ず読む。

## 実装参照

| 形式 | 主な実装 |
|------|----------|
| Preset / PadDefinition | `JPad/Models/Preset.swift`, `JPad/Models/Preset+Codable.swift`, `JPad/Models/PadDefinition.swift` |
| 共有 export envelope | `JPad/Services/PresetLoading/PresetImportExportService.swift` |
| `.jpd` ZIP | `JPad/Services/PresetLoading/PresetShareZipArchive.swift` |
| ローカル保存 index / slot | `JPad/Services/PresetLoading/PresetLibraryModels.swift`, `JPad/Services/PresetLoading/UserPresetLibrary.swift` |
| TinyTone patch | `JPad/Services/Audio/TinyTonePatch+Factory.swift`, `../tinytone` 側の TinyToneCore |
| App Group shared patch | `JPad/Services/Midi/MidiOutputService.swift`, `docs/TINYTONE_APP_GROUP_SHARING.md` |

## 1. `.jpd`

- JPad の共有・取り込み用ファイル。
- 中身は JSON ベースの export envelope を ZIP で包む形式。
- 共有シート、AirDrop、外部ファイル受け渡しで使う。
- ローカル保存の正本ではない。

想定用途:

- 共有
- バックアップ
- 他端末への受け渡し

## 1.5 共有・取込で受ける拡張子

現行実装は `.jpd` だけを読むわけではない。

- 共有の主経路: `.jpd`
- 直接 JSON export: `.json`
- 互換入力: `.zip`、`.jch`、`.jchord.zip`、`.jchord.json`、`.jchord`

つまり、`.jpd` は中心形式だが、取込互換性はそれより広い。

## 2. TinyTone patch

- TinyTone の音色本体 JSON。
- App Group 共有の patch file も、この形式を正本として使う。
- 共有用のメタ情報は別ファイルに分ける。
- patch 本体はできるだけ既存 decode 経路で読める形を維持する。
- JPad の `Preset` と TinyTone patch は同じ形式ではない。
- TinyTone patch のスキーマ判断は JPad 側だけで完結させず、必要なら `../tinytone` の実装も確認する。

## 3. App Group 共有データ

App Group 側は 2 層に分ける。

```text
TinyToneSharedPatches/
  index.json
  patches/
    <patch-id>.json
```

- `index.json` は一覧とメタデータ。
- `patches/*.json` は音色本体。
- 破損時は index 単位、patch 単位で部分除外できる構造にする。
- JPad では選択済み共有 patch が消えた場合に備え、fallback cache と factory preset fallback の扱いを確認する。
- 共有 patch は JPad ローカル preset slot の正本ではない。

## 4. ローカル保存

JPad のユーザーセットはローカル保存が正本。

```text
Application Support/JPad/library/user/
  index.json
  presets/{uuid}.json
```

### index.json

- アクティブスロット
- 初回シード済みフラグ
- スロット一覧
- origin / seed / store の区別
- store 由来 slot と user 由来 slot は課金 gate が違う。

### presets/{uuid}.json

- 保存日時
- 元テンプレート
- 由来
- `Preset` 本体

`Preset` は `transposeSettings`(モード・シフトメモリー)に加えて、RIFF / SEQ 用の `sequencerSettings`(BPM、RIFF 4 スロット + 基準キー、SEQ 4 スロット)を持つ。旧 JSON に `sequencerSettings` が無い場合はデフォルト値で decode する。RIFF は旧称 ARP からのリネームで、`sequencerSettings.arp` キー・`padControlMode` の旧 `arp` 値は decode 時に `riff` へマップする(`docs/RIFF_SEQ_REQUIREMENTS.md` 参照)。RIFF の `steps` は 4 声(`U/M1/M2/L`)で保存する。旧 3 声(`U/M/L`)データは読み込み時に `U/M1/空/L` へ正規化する。

## 4.5 共有 export の JSON 本体

`.jpd` の中身、および直接 `.json` export の本体は `PresetExportEnvelope`。

- `formatVersion`
- `kind`
- `exportedAt`
- `slotName`
- `origin`
- `sequencerSettings`（RIFF / SEQ 設定。`preset.sequencerSettings` と同じ内容を明示的に持つ）
- `preset`

この envelope を ZIP に包んだものが `.jpd`。JSON 単体 export では同じ envelope をそのまま出す。
`preset` 内にも `sequencerSettings` は含まれるが、IMPORT / EXPORT / AirDrop の往復で RIFF / SEQ 情報が落ちないよう、共有 envelope 直下にも同じ設定を入れる。読み込み時は envelope 直下の値があればそれを `preset` へ反映する。RIFF 4 声の `steps` もこの経路でそのまま共有する。
読み込み側は `.jpd` 以外の互換拡張子も受けるため、UI copy と importer の実装を混同しない。

## 5. 保存数制限

現状の前提は次の通り。

| 区分 | 上限 |
|------|------|
| 無料ユーザーセット | 5 |
| Pro ユーザーセット | 100 |
| store 由来の同時保持 | 無料は 1 件、Pro は無制限 |

## 6. 互換性ルール

- 既存 JSON はできるだけ壊さない。
- 新しい項目は optional から始める。
- 読み込み時は未知フィールドを無視できる形を保つ。
- 保存時は、必要な場合だけ新しい formatVersion を上げる。
- 「今の UI で主に使う形式」と「実装が読み込める互換形式」を混同しない。
- decode を狭くする変更は避ける。古い `.jpd`, `.json`, `.jchord` 系 import を壊さない。
- field rename が必要な場合は、旧 field decode と新 field encode の移行期間を置く。

## 7. RAG に入れるときの注意

- この文書、`ARCHITECTURE.md`、`PRESET_LIBRARY.md`、`PRESET_STORAGE.md`、`TINYTONE_APP_GROUP_SHARING.md` は RAG に入れてよい。
- `Preset+Codable.swift` や `PresetImportExportService.swift` は、RAG には要約を入れてもよいが、実装時は必ず現行ファイルを直接読む。
- 古い RAG 結果が import/export の実装と食い違う場合、現行 Swift 実装を優先してこの文書を更新する。
