# PAD 編集 UI 1.1 仕様（検討・実装中）

## EDIT モードからの遷移

- パッド **本体タップ** → キー入力ポップアップ（`PadKeyInputEditorSheetV11`）。
- パッド右上 **鍵盤マーク（pianokeys）を押し続け** → そのパッドの和音を試聴（通常プレイと同じ MIDI OUT）。マーク以外は INPUT NOTE を開く。
- 旧フル画面 `PadEditorView` への直接遷移はメイングリッド EDIT からは行わない。

## ポップアップ内画面

| 画面 | 左上 | 下部ボタン |
|------|------|------------|
| **ノート入力**（既定） | **LABEL** → ラベル編集へ | CANCEL / SET |
| **ラベル編集** | **KEYS** → ノート入力へ | CANCEL / SET |

ポップアップ幅: 左右 **10pt** マージン。最大 **縦 360pt / 横 560pt**（内側パーツはチップ幅・鍵間隔を自動調整）。

**外側タップ**: 暗い背景をタップしてもポップアップは閉じない（CANCEL / SET のみ）。背面のパッドやキーボードのフォーカスも外さない。

ラベル編集レイアウト:

```
[KEYS]
LABEL        [ 入力欄（1行）     ]
CANDIDATES   [ チップ… ]  ← 入力欄と左ライン揃え、外枠なし
CANCEL  SET  ← ポップアップ内幅の半分ずつ（`v11PopupFooterButtonWidth`、PAD の cellSide とは無関係）
```

候補は `labelEditorCandidates`（**ROOT** = `bassNotes` のルート、**VOICING** = `chordNotes` で `ChordCandidateRecognizer` を再計算。ROOT 変更でラベルルートも同期）。

## ROOT 表示の基準（NOTE INPUT）

NOTE INPUT で「ROOT」と書いてあるものは **ベース音（`bassNotes`）** 用。コード名（`label`）やパッドの `root` プロパティは **ROOT 行には出さない**（ROOT ボタン押下や MIDI≦60 で内部同期）。

| UI | 何を見ているか | いつ変わるか |
|----|----------------|--------------|
| **ROOT 右の音名**（例 `C#`） | `editingBassNotes` の **最低音**のピッチクラスだけ | ROOT ボタン、MIDI≦60 代理、CLR。空なら非表示 |
| **12 鍵・渋オレンジ** | 現在 OCT にある `bassNotes` + `chordNotes` | ADD、DEL、MIDI、CLR、OCT 変更 |
| **12 鍵・選択ハイライト** | `selectedKeyRoot`（まだ bass にしない操作対象） | 12 鍵タップ。DEL/ROOT はここが空なら無効 |
| **12 鍵・明るいオレンジ** | 鍵を押している間の試聴 | 指を離すと解除 |

**12 鍵の選択 ≠ ROOT 右の表示**

- 鍵を選んだだけでは ROOT 右は変わらない（ADD は chord、ROOT ボタンで初めて bass 確定）。
- ROOT 右は **すでに bass として保存されている音** のルート名。

### 例: Generic Jazz の PAD 11（`Bb13` / 内部 `id` 10）

プリセット `jazz-progression.json` の保存値:

| フィールド | MIDI | 音名（参考） |
|------------|------|--------------|
| `bassNotes` | 46, 58 | Bb2, Bb3（ベース 2 音） |
| `chordNotes` | 53, 57, 62, 67 | F3, A3, D4, G4 |

NOTE INPUT を開いた直後の目安:

| UI | この PAD では |
|----|----------------|
| **ROOT 右** | **Bb** 1 つだけ（`bassNotes` の最低音 46 のピッチクラス。58 も Bb だが ROOT 右には出さない。旧実装は 46/58 を並べて `Bb, Bb` になっていた） |
| **OCT 初期** | コードが C3/C4 にまたがるが、ゾーン数は同数 → **C3** 側（小さいゾーン） |
| **12 鍵・渋オレンジ（OCT=C3）** | **Bb, F, A**（この OCT にある bass/chord のルート色。Bb2 の 46 は C2 ゾーンのため C3 では出ない） |
| **12 鍵・選択** | 未操作ならなし（`selectedKeyRoot` は空） |

ラベルは `Bb13` だが、ROOT 行はラベルではなく **bass の最低音** を見る。ベースが 2 オクターブに分かれている PAD では、OCT を C2 に下げると渋オレンジに **Bb2** も出る。

**ラベル画面（CANDIDATES）のルート**は別: `bassNotes` 先頭 → ラベルからパース → `root`（`v11RootForCandidates`）。VOICING は `chordNotes` のみ。

## ROOT と `bassNotes` / `chordNotes`（v1.1）

JSON プリセットは **`bassNotes` と `chordNotes` を別フィールド**で持つ。UI の **ROOT** は「ベース音 = `bassNotes`」。**12 鍵の ADD では 60 ルールは使わない**（現在 OCT の鍵をそのまま chord に入れる）。

### 何がどこに入るか

| 経路 | 入る先 | 条件 |
|------|--------|------|
| **ROOT ボタン** | `editingBassNotes`（通常 1 音） | 12 鍵で鍵を選び **ROOT** を押したとき。現在 OCT のその鍵 1 つだけ |
| **ADD** | `editingChordNotes` | 12 鍵で鍵を選び **ADD**。現在 OCT のその鍵 |
| **DEL** | 両方から削除 | 選択鍵を現在 OCT から削除（bass / chord どちらにあっても） |
| **MIDI 入力** | `chordNotes` ＋条件付き `bassNotes` | 受信音は **すべて** キーゾーンのまま `chordNotes`（≦60 含む）。**MIDI ≦ 60 の最低音** は追加でルート代理（`bassNotes`）。C0…C9 外は無視 |
| **CLR** | 両方クリア | `editingBassNotes` + `editingChordNotes` を空に |
| **ポップアップ開始** | 読み込みのみ | プリセットの `bassNotes` / `chordNotes` をそのまま `editing*` にコピー |

**入らない例（v1.1）**

- 12 鍵の **ADD** では `bassNotes` に入れない（ROOT ボタンまたは MIDI 60 ルールのみ）
- MIDI で **≦ 60 の音が無い** バッチではルート代理なし（既存 ROOT は維持。後から ROOT ボタンで変更可）

### ROOT / bass が使われる場面

| 用途 | 内容 |
|------|------|
| **ROOT 行の表示** | `v11BassNotesLabel` — `bassNotes` の **最低音**のルート名だけ（例 `C#`）。オクターブ番号は出さない |
| **OCT 表示** | ボイシング最多ゾーン（同数なら低い方）。chord 空時は bass のゾーン |
| **12 鍵の渋オレンジ** | 現在 OCT 内の **`bassNotes` + `chordNotes`** のピッチクラス（ベースも上声部も同じ表示） |
| **CANDIDATES** | **ルート** = `editingBassNotes` 先頭のピッチクラス（なければラベル → `root`）。**ボイシング** = `chordNotes` のみで `ChordCandidateRecognizer` |
| **ROOT 押下後** | `root` プロパティと `label` のルート文字をベースに合わせる（例 `Am7` → `Gm7`） |
| **SET 保存** | `draftPadFromEditing()` が `bassNotes` / `chordNotes` を JSON どおり書き出し |
| **試聴・MIDI OUT** | `bassNotes + chordNotes` をまとめて発音 |

### コード名（ラベル）との関係

- **表示名・ラベル**（`label`）は別フィールド。手入力または CANDIDATES で決める。
- **ROOT（bass）** は「このコードを **どのルート音で解釈するか**」のための値。上声部（`chordNotes`）だけ変えても、ROOT を変えれば CANDIDATES は別のコード名になる。

### 実装メモ

- v1.1 MIDI: `PadEditorViewModel+KeyInputV11.appendMidiNotesToChordKeys`
- v1.1 ROOT 操作: `assignRootFromSelectedKey()`
- 候補: `v11RootForCandidates` + `v11VoicingNotesForCandidates` → `labelEditorCandidates`
- v1.1 MIDI 60 ルール: `midiProxyRootMaxNote`（60）、`appendMidiNotesToChordKeys`
- v1 切り戻し: 従来どおり全ノートを 60 未満/以上で bass/chord 分割

## ポップアップ構成（v1.1・ノート入力）

```
┌─────────────────────────────────────────┐
│ [LABEL]  <    C0    >            [🎹]   │  1行目: ラベル編集 / OCT / 試聴
├─────────────────────────────────────────┤
│ 12鍵（現在 OCT 音域の bass+chord を渋オレンジ）│  2行目
├─────────────────────────────────────────┤
│ ROOT [C#]  ADD  DEL  CLR                │  3行目
├─────────────────────────────────────────┤
│        CANCEL          SET              │  4行目
└─────────────────────────────────────────┘
```

チップ・表示行は **なし**。

### 操作フロー

| 操作 | 手順 |
|------|------|
| **登録** | 12 鍵を押して選択 → **ADD**（現在 OCT に登録）。**MIDI** は ADD 不要で自動登録 |
| **ボタン** | **ADD / ROOT / CLR** は常に有効表示。**DEL** は 12 鍵選択時のみ |
| **削除** | 12 鍵を押して選択 → **DEL**（現在 OCT から削除） |
| **ROOT** | 12 鍵を選択 → **ROOT**（現在 OCT のベースとして `bassNotes` に反映）。**Bass は ROOT 右のルート名のみ**（例 `C#`） |
| **MIDI** | ADD 不要で自動登録。受信音はすべて input key（`chordNotes`、≦60 も含む）。**≦ 60 の最低音** はルート代理（`bassNotes`）。表示 OCT はバッチ内の最後の音。後から ROOT で差し替え可 |
| **CLR** | 全ノート削除 |
| **OCT** | `<` `>` で C0…C9。`<` 左 / `>` 右にインジケータ1つ（下記） |

**OCT シフトインジケータ**（`bassNotes` + `chordNotes` をゾーン単位で判定）:

| 色 | 条件（`<` 左 / `>` 右それぞれ独立） |
|----|--------------------------------------|
| **緑** | 現在 OCT の **直上／直下 1 oct** にコード情報がある |
| **黄** | 直上／直下 1 oct には **なく**、**2 oct 以上離れた**ゾーンにのみある |
| なし | その方向にコード情報がない |

緑と黄が両方あり得る場合は **緑を優先**（±1 oct にあれば黄にしない）。
| **OCT 表示** | 12 鍵は **`chordNotes`（ボイシング）が最も多いキーゾーン** を表示。同数なら **低い** ゾーン。chord が空のときは `bassNotes` のゾーン（なければ C2）。`<` `>` で手動変更可 |
| **試聴** | 鍵盤アイコンで登録済み全ノート |

12 鍵は **白枠**（`padBorder`）。選択・登録済みは渋オレンジ、押下試聴中は明るいオレンジ。

## 関連コード

- `PadKeyInputEditorSheetV11.swift`
- `PadEditorViewModel+KeyInputV11.swift`
- `PadEditorRootKeyboardView.swift`
