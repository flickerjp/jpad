# TinyTone / JPad App Group 共有案

目的: TinyTone で作成した音色を、ファイルの LOAD / EXPORT 操作を介さず JPad から使えるようにする。現状の **TinyTone LOAD / EXPORT** と **JPad の JSON LOAD** は残し、App Group は次バージョン以降の追加経路として併用する。

## 現状

| アプリ | 現在の保存・入出力 |
|--------|--------------------|
| TinyTone | `TinyTonePatchDocument` による JSON `LOAD` / `EXPORT`。ユーザースロットは `UserDefaults` の `TinyTone.userSlots` に `[TinyTonePatch]` として保存 |
| JPad | 設定の TinyTone 音色はファクトリ 5 件 + TinyTone App Group ライブラリ参照へ寄せる。JPad 側の音色 JSON `LOAD` は当面追加しない |

この経路は互換性のため維持する。App Group は「ファイル共有 UI を開かなくても、同じ端末内の TinyTone 音色を JPad が見つける」ための追加レイヤーにする。

## 結論

推奨案は **TinyTone の保存ライブラリを App Group へ移行 + JPad 側キャッシュ**。

- TinyTone は保存音色の正本を App Group コンテナへ移す。
- 既存の TinyTone ユーザースロット x5 は、次回起動時に App Group ライブラリへマイグレーションする。
- TinyTone 無料版は App Group ライブラリ内で保存 5 件まで、TinyTone Pro で保存件数を実質無制限に拡張する。
- JPad は無料版でも共有コンテナを読み、音色選択肢に `shared:<id>` として表示する。
- JPad が共有音色を選択したら、その時点の JSON bytes を JPad 側にもキャッシュする。
- 共有音色が後で消えた場合でも、最後に選んだ音色はキャッシュから鳴らせる。
- JPad 側の音色 LOAD は当面なし。音色追加・削除・EXPORT は TinyTone 側の App Group ライブラリ管理に寄せる。

## 有料機能の位置づけ

TinyTone と JPad は別アプリだが、この連携では TinyTone 側の課金を中心に扱う。JPad 側でさらに Pro ロックを重ねると、同じユーザーに二重課金感が出るため、JPad の読み込みは無料機能として持たせる。

| アプリ | 有料化の対象 | 無料/既存で残すもの |
|--------|--------------|--------------------|
| TinyTone | App Group 保存ライブラリの 5 件超、将来の MIDI 化、GarageBand プラグイン対応を年間有料オプションとして検討 | 既存の音色作成、5 件までの保存、JSON LOAD / EXPORT |
| JPad | なし。App Group 読み込みは無料版にも入れる | ファクトリ音色、App Group 読み込み、基本演奏 |

TinyTone 側の有料機能は「保存音色ライブラリを 5 件超に拡張する権利」。JPad 側はそれを読むだけなので、JPad の Pro entitlement とは切り離す。

| 状態 | 挙動 |
|------|------|
| TinyTone 有料 / JPad Free または Pro | TinyTone の App Group ライブラリ内の音色を JPad の `From TinyTone` に表示して選択可能 |
| TinyTone Free / JPad Free または Pro | TinyTone の App Group ライブラリ 5 件までを JPad の `From TinyTone` に表示して選択可能 |
| TinyTone 未導入 / JPad Free または Pro | JPad は既存のファクトリ音色と JSON LOAD 経路のみ |

## 保存領域の棲み分け

結論: TinyTone の保存正本を **App Group ライブラリ** に寄せる。既存の **TinyTone x5** は初回移行元として扱い、移行後は「無料上限 5 件」という意味に変える。**JPad x1** は手動 JSON LOAD の互換枠として維持する。

| 領域 | 所有アプリ | 役割 | 有料判定 | 上書き関係 |
|------|------------|------|----------|------------|
| TinyTone legacy user slots x5 | TinyTone | 旧保存領域。次回起動時に App Group へマイグレーションする移行元 | 移行後は直接使わない | 移行後は読み取り fallback のみ。新規保存先にしない |
| App Group TinyTone library | TinyTone が writer、JPad が reader | TinyTone の保存正本。無料は 5 件まで、TinyTone Pro で 5 件超を許可 | TinyTone 側の 5 件超は年間オプション。JPad 側 read は無料 | JPad x1 を上書きしない。削除/改名/並べ替えは TinyTone 側で管理 |
| TinyTone JSON LOAD / EXPORT | TinyTone | 手動バックアップ、他端末共有、互換経路 | 既存通り残す | App Group と独立 |
| JPad sound LOAD | JPad | 当面なし。音色の追加管理は TinyTone 側に寄せる | なし | JPad 内で音色管理を二重化しない |
| JPad shared cache x1 | JPad | 最後に選択した共有音色の fallback | 無料 | 共有ファイル消失時の再生継続用 |

この形では、TinyTone 側に **Publish to JPad** という別操作を置かない。TinyTone で保存された音色は App Group ライブラリに入り、JPad はその一覧を読む。削除、改名、並べ替え、上限管理は TinyTone 側で行う。

無料版 TinyTone では保存上限を 5 件にする。Pro では 5 件を超えて保存できる。JPad から見ると `From TinyTone` の候補数が増えるため、JPad の音色選択肢は TinyTone Pro の保存数に応じて拡張される。

JPad では音色 JSON LOAD を出さず、`shared:<id>` を TinyTone 管理音色として表示する。

```text
From TinyTone
  Warm Keys                 // TinyTone App Group。JPad 側で管理しない
  Soft Lead
```

TinyTone の App Group ライブラリ内の音色は `From TinyTone` に複数並ぶため、実用上は JPad の音色選択肢が無制限に近く拡張される。JPad 内で直接編集・保存する枠ではないので、音色管理の責務は TinyTone に一本化できる。

## App Group

候補:

```text
group.com.flickerproduct.tinytone
```

最終名は Apple Developer の App Groups 登録時に確定する。JPad の bundle id は移行後も `com.flickerproduct.jchord`、TinyTone は `com.jflickeys.tinytone`。同一 Team ID `G942ZU3CGC` 配下なので、両ターゲットに同じ App Group capability を付ける。

必要な変更:

| 対象 | 変更 |
|------|------|
| JPad | `.entitlements` 追加、`project.yml` / `JPad.xcodeproj` に App Groups capability |
| TinyTone | `.entitlements` 追加、`project.yml` / `tinytone.xcodeproj` に App Groups capability |
| Apple Developer | App Group ID を作成し、両 App ID に紐付け |

## 共有コンテナ構造

`FileManager.default.containerURL(forSecurityApplicationGroupIdentifier:)` で取得した URL の下に、JPad/TinyTone 専用ディレクトリを作る。

```text
<AppGroup>/
  Library/
    Application Support/
      TinyToneSharedPatches/
        index.json
        patches/
          <patch-id>.json
```

`UserDefaults(suiteName:)` に大きい JSON blob を入れない。パッチ本体はファイル、一覧だけ `index.json` にする。理由は、サイズ増加・atomic write・破損時の復旧を扱いやすくするため。

## index.json

```json
{
  "version": 1,
  "updatedAt": "2026-05-26T00:00:00Z",
  "items": [
    {
      "id": "D2A8F6B6-8B62-4F3F-9D6A-8C72D18E87E0",
      "patchName": "Warm Keys",
      "fileName": "D2A8F6B6-8B62-4F3F-9D6A-8C72D18E87E0.json",
      "updatedAt": "2026-05-26T00:00:00Z",
      "sourceBundleID": "com.jflickeys.tinytone",
      "sourceAppName": "TinyTone",
      "schemaVersion": 1
    }
  ]
}
```

パッチ本体の `<patch-id>.json` は現行 `TinyToneJSONService` が読める `TinyTonePatch` JSON とする。独自 envelope で包むと既存の decode 経路を再利用しにくいため、メタデータは `index.json` に寄せる。

## TinyTone 側の役割

TinyTone を **App Group ライブラリの唯一の writer** とする。

| 操作 | 処理 |
|------|------|
| 起動時 | App Group が使える場合、共有 index を読み込む。未移行なら旧 `TinyTone.userSlots` を App Group へマイグレーション |
| SAVE | App Group ライブラリへ保存。無料版は 5 件上限、TinyTone Pro は 5 件超を許可 |
| EXPORT | 既存 FileDocument export のまま。App Group 共有とは別経路 |
| LOAD | 既存 JSON LOAD のまま。読み込んだ音色は App Group ライブラリへ取り込み可能 |
| Export from Library | App Group ライブラリ内の選択音色を既存 FileDocument export で JSON 書き出し |
| 削除 | App Group index から外し、対応ファイルを削除。JPad 側キャッシュは消さない |

現在編集中の未保存パッチは App Group に書かない。JPad に見える対象は TinyTone で保存済みの音色だけにする。

## 未保存ドラフト復元

TinyTone はアプリを完全終了しても、次回起動時に未保存の編集状態から再開できるようにする。

| 領域 | 役割 |
|------|------|
| App Group library | 保存済み音色の正本。JPad に見える |
| TinyTone draft | TT ローカルの未保存編集状態。JPad には見せない |

方針:

- パラメータ編集、LOAD 後の未保存状態、名前変更中のパッチを draft として TT ローカルに保持する。
- draft は App Group `index.json` には載せない。保存済みとして扱わず、JPad の `From TinyTone` にも出さない。
- TT 起動時は draft があれば「前回の未保存編集」を復元する。
- ユーザーが `SAVE` した時点で App Group library へ保存し、draft をクリアまたは保存済み内容に同期する。
- ユーザーが明示的に破棄/RESET した場合だけ draft を消す。

保存先は `UserDefaults` または TT アプリ専用 `Application Support` を候補にする。App Group に置く場合でも、`Draft/` など保存済みライブラリとは別ディレクトリにし、JPad reader は参照しない。

## LOAD / EXPORT と App Group

既存の JSON LOAD / EXPORT は維持しつつ、保存正本が App Group へ移る前提で役割を整理する。

| 操作 | 役割 | 上限 |
|------|------|------|
| LOAD JSON | 外部 JSON を読み込み、確認後に App Group ライブラリへ追加する | 追加保存なので TinyTone 無料版は 5 件上限、Pro は 5 件超 |
| EXPORT JSON | App Group ライブラリ内の選択音色を JSON として書き出す | 書き出し自体は既存互換機能として残す |
| SAVE / Duplicate | 現在編集中の音色を App Group ライブラリへ保存、または既存音色から複製 | 追加保存なので TinyTone 無料版は 5 件上限、Pro は 5 件超 |

LOAD した JSON を即時に App Group へ保存するか、いったん編集画面へ読み込んでから `SAVE` させるかは UI で選べる。安全側は **読み込み後に確認して保存**。既存スロットを直接上書きするより、ライブラリに新規追加する方が事故が少ない。

EXPORT は App Group の存在に依存した独自形式にしない。これまで通り `TinyToneJSONService` が読める単体 `TinyTonePatch` JSON を出す。これにより、他端末・バックアップ・将来の互換経路を維持できる。

## 旧 x5 からのマイグレーション

TinyTone の次回起動時に、旧 `UserDefaults` の `TinyTone.userSlots` を App Group ライブラリへ移す。

1. App Group container URL を取得できるか確認する。
2. `index.json` が存在しない、または `migration.legacyUserSlotsImported` が未完了なら旧 x5 を読む。
3. 空スロット/初期値相当を除外するか、現行 UI の見え方を優先して 5 件すべて移すかを実装時に決める。安全側は 5 件すべて移行。
4. 各スロットに stable id を付け、`patches/<id>.json` と `index.json` を atomic write する。
5. 成功後に App Group 側の migration flag を立てる。
6. 旧 `TinyTone.userSlots` はすぐ削除せず、1-2 バージョンは fallback として残す。

移行後の新規保存先は App Group のみ。旧 x5 は新規書き込み先に戻さない。

## JPad 側の役割

JPad は共有コンテナを **read mostly** として扱う。初期実装では JPad から共有ライブラリへ書き戻さない。

| 操作 | 処理 |
|------|------|
| 起動 / foreground / 設定表示 | 共有 index を読み直し、存在するパッチだけ候補に追加 |
| 音色リスト | ファクトリ 5 件、共有 `shared:<id>` を並べる。JPad 側の音色 LOAD は出さない |
| 共有音色選択 | `patches/<id>.json` を decode し、`TinyToneEngine.prepareSoundPatch` / `loadSoundPatch` へ渡す |
| 選択時キャッシュ | 選択した共有 JSON bytes を JPad UserDefaults に保存し、共有ファイル消失時の fallback にする |
| 音色追加/削除 | JPad では行わない。TinyTone 側 App Group ライブラリで管理 |

追加する保存キー案:

| キー | 用途 |
|------|------|
| `previewSoundSelectedPresetID` | `factory:*` / `shared:<id>` を保存 |
| `previewSoundSharedPatchCacheData` | 最後に選択した共有音色の JSON bytes |
| `previewSoundSharedPatchCacheID` | キャッシュ元の shared id |
| `previewSoundSharedPatchCacheName` | 表示 fallback 用の名前 |

既存リリースで `previewSoundCustomPatchData` が存在する場合は移行互換として読む余地を残すが、新規 UI としての音色 LOAD は出さない。将来削除する場合は、選択中ユーザーへの fallback を確認してから行う。

## UI 方針

JPad 設定の TinyTone 音色欄に、共有音色がある場合だけ追加表示する。JPad 側では Pro ロックしない。

```text
Factory
  TinyTone
  TinyPiano
  TinyOrgan
  TinyStrings
  TinySynth

From TinyTone
  Warm Keys
  Soft Lead
```

TinyTone が未インストール、App Group 未設定、共有音色なしの場合は `From TinyTone` セクションを出さない。ユーザーに空状態やエラーを見せすぎない。

## 破損・不整合の扱い

- `index.json` が読めない場合: 共有候補を出さない。既存ファクトリ/カスタムは通常通り。
- index にあるファイルが存在しない場合: その item だけ除外。
- パッチ JSON decode 失敗: その item だけ除外し、JPad の通常動作は止めない。
- 選択済み `shared:<id>` が消えた場合: `previewSoundSharedPatchCacheData` が decode できればそれを使う。無ければ `factory:TinyTone` に戻す。
- TinyTone 側で削除された音色は JPad の一覧から消す。JPad が最後に選択していた音色だけは cache fallback で鳴らせるが、一覧には復活させない。
- TinyTone / JPad の `TinyToneCore` schema がずれた場合: decode できる範囲で読み、失敗時は候補から除外。両アプリのリリースでは同じ `TinyToneCore` 世代に揃える。

## 書き込み安全性

- パッチファイルを書いてから `index.json` を更新する。
- 書き込みは `.atomic` を使う。
- 削除は index から外した後にファイル削除する。削除失敗は致命扱いにしない。
- JPad は foreground / 設定表示時に再スキャンする。リアルタイム同期通知は初期実装では不要。

## 実装候補

共通コードとして `TinyToneSharedPatchLibrary` を `TinyToneCore` ではなく各アプリ側に置く案が現実的。`TinyToneCore` は DSP / patch model の正本に留め、iOS App Group 依存を入れない。

```swift
struct TinyToneSharedPatchIndex: Codable {
    var version: Int
    var updatedAt: Date
    var items: [TinyToneSharedPatchItem]
}

struct TinyToneSharedPatchItem: Codable, Identifiable {
    var id: String
    var patchName: String
    var fileName: String
    var updatedAt: Date
    var sourceBundleID: String
    var sourceAppName: String
    var schemaVersion: Int
}
```

JPad 側は `PreviewSoundPresetIDs` に以下を追加する。

```swift
static func sharedID(_ id: String) -> String { "shared:\(id)" }
static func sharedPatchID(from presetID: String) -> String? { ... }
```

## 段階計画

1. **設計のみ**: この文書を正本にし、現行 JSON LOAD/EXPORT は触らない。
2. **Entitlement 準備**: Apple Developer / XcodeGen / project file に App Group を追加。両アプリで container URL が取れることを確認。
3. **TinyTone migration**: 旧 `TinyTone.userSlots` x5 を App Group ライブラリへ移行し、以後の保存正本を App Group にする。
4. **JPad reader**: JPad 無料版でも共有 index を読み、`shared:<id>` を音色候補へ追加。選択時は cache fallback を保存。
5. **実機検証**: TinyTone で保存 → JPad foreground → 候補表示 → 選択 → 機内モード/再起動/片方未インストールで動作確認。

## 採用しない案

| 案 | 採用しない理由 |
|----|----------------|
| JPad 側に音色 LOAD を追加 | TinyTone 側 App Group ライブラリと管理責務が二重化する |
| App Group `UserDefaults` に `[TinyTonePatch]` を保存 | blob が大きくなりやすく、atomic write / 破損復旧が弱い |
| 旧 TinyTone x5 と App Group の二重保存を長期運用 | 正本が分かれ、削除/改名/並べ替えの同期不整合が起きる |
| JPad から TinyTone ユーザースロットへ直接書き戻す | 初期実装の責務が増え、衝突解決 UI が必要になる |
| UIDocumentPicker の自動化 | ユーザー操作が必要で、今回の「JSON入出力を介さない」目的に合わない |

## 関連ファイル

JPad:

- `JPad/Services/Midi/MidiOutputService.swift` — preview sound preset 選択、JSON LOAD、UserDefaults 保存
- `JPad/Features/MidiRouting/MidiSettingsView.swift` — JPad 側 JSON LOAD UI
- `JPad/Models/PreviewSoundPresetOption.swift` — 音色候補モデル
- `docs/TINYTONE_AUDIO.md` — 現行 TinyTone 内蔵音の正本

TinyTone:

- `/Users/tone/work/tinytone/TinyToneTuner/App/TinyToneStore.swift` — JSON import/export、ユーザースロット保存
- `/Users/tone/work/tinytone/TinyToneTuner/Services/TinyTonePatchDocument.swift` — FileDocument JSON LOAD/EXPORT
- `/Users/tone/work/tinytone/TinyToneTuner/Views/PatchEditorView.swift` — TinyTone 側 LOAD / EXPORT UI
