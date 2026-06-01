# DATA_FORMATS.md

JPad が扱う主要データ形式のメモ。

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

### presets/{uuid}.json

- 保存日時
- 元テンプレート
- 由来
- `Preset` 本体

## 4.5 共有 export の JSON 本体

`.jpd` の中身、および直接 `.json` export の本体は `PresetExportEnvelope`。

- `formatVersion`
- `kind`
- `exportedAt`
- `slotName`
- `origin`
- `preset`

この envelope を ZIP に包んだものが `.jpd`。JSON 単体 export では同じ envelope をそのまま出す。

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
