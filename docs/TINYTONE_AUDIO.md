# 内蔵 TinyTone オーディオ（PAD OUT）

内蔵プレビュー音（設定の **PAD OUT → TinyTone**）の **本線仕様**。挙動が分散していて分かりにくいため、変更前にここを参照する。

## 本線（Debug / Release 共通）

| 項目 | 内容 |
|------|------|
| 唯一の内蔵エンジン | `MidiOutputService` が常に `TinyToneEngine()` を保持（`InternalPreviewSynth`） |
| ビルド切替 | **なし**（`TINYTONE_ENGINE_TEST` や `#if DEBUG` 分岐は廃止済み） |
| DSP | TinyToneTuner から移植したフル `TinyToneEngine` + JSON パッチ |
| 旧実装 | `TinyPianoEngine` は削除（コミット `1455292` 以降、全ビルドでパッチ駆動） |

**経緯（読み飛ばしてよい）:** 一時期 `80bdf77` で Debug 向けに TinyTone 経路を試し、その後 `1455292` で本線化。以降「デバッグ用経路」と「製品経路」の二重系統はない。

## 概要

| 層 | 実装 |
|----|------|
| ルーティング | `MidiOutputService`（`outputRoute == .tinyPiano` … **歴史的な enum 名**） |
| エンジン | `TinyToneEngine`（TinyToneTuner と同一 DSP） |
| 音色 | `TinyTonePatch` JSON。ファクトリ 5 + カスタム 1（LOAD） |
| UI 表示名 | `settings.pad_out.tiny_piano` → 文言は **「TinyTone」** |
| コード上の起動 API 名 | `ensureTinyPianoReady()` など **TinyPiano プレフィックスは互換用のまま**（中身は TinyTone） |

内蔵ルート（`outputRoute == .tinyPiano`）を選んでいる限り、常に `TinyToneEngine` が鳴る。

## UI 状態の二系統（齟齬しやすい）

遅延ウォームアップのため、**「ルートが選ばれている」** と **「AVAudioEngine が起動済み」** は別フラグ。

| フラグ / API | 内蔵 TinyTone 時の意味 |
|--------------|------------------------|
| `hasActiveMidiOutput` | ほぼ常に `true`（内蔵ルートならパッド送信を許可。エンジン未起動でも `sendPadOn` 内で起動する） |
| `isInternalPreviewReady` | `previewEngine.start()` 成功後のみ `true` |
| 設定のオレンジ文言 | `outputRoute == .tinyPiano && !isInternalPreviewReady` のとき `lastMidiEventDescription` を表示（ウォームアップ前は「未起動」扱いの見た目） |

ドキュメントや UI を書くとき、「PAD OUT が TinyTone なのに Ready でない」は **コールドスタート〜ウォームアップ前の正常状態** があり得る。

## 既存ユーザー（アップデート）

- **PAD OUT** の UserDefaults（`selectedMidiOutputRoute` = `tinyPiano`）はそのまま → 引き続き内蔵音。
- **プリセット ID**（`previewSoundSelectedPresetID`）が無いユーザーは、起動時にファクトリ 1 番 **`TinyTone`** を適用（`bootstrapPreviewSoundPresets`）。旧内蔵音も TinyTone 系の想定のため、意図的にそのまま。
- 旧キー `previewSoundPatchData` だけある場合 → `previewSoundCustomPatchData` へ移し、可能なら **カスタム** プリセットとして選択（`migrateLegacyPreviewSoundIfNeeded`）。
- 外部 MIDI / GarageBand のみのユーザーはエンジン切り替えの影響を受けない。

## エンジン起動タイミング（重要）

起動直後のポップ／ノイズを避けるため、**アプリ起動時は AVAudioEngine を鳴らさない**。

| タイミング | 処理 |
|------------|------|
| `MidiOutputService.init` / `finalizeAudioSessionForCurrentRoute` | オーディオ **セッションのみ**（`activatePreviewAudioSessionIfNeeded`） |
| `preparePreviewAudioIfNeeded`（`.task` / `MainView.onAppear` 等） | 同上（セッションのみ） |
| **「JPad をはじめる」**（`OnboardingView.finishOnboarding`） | `warmUpPreviewEngineIfNeeded()` → 初回 `start()` |
| **設定シートを閉じる**（`MidiSettingsView.onDisappear`） | 同上 |
| 初回パッド / TEST NOTE 押下 | `ensureTinyPianoReady()` → `previewEngine.start()`（フォールバック） |
| フォアグラウンド復帰 | `preparePreviewAudioAfterReturningToForeground` … **バックグラウンド前にエンジンが動いていたときだけ** 再開 |

`selectTinyPianoOutput` はルート保存のみで、**エンジンは起動しない**（初回パッドまで遅延）。

## ウォームアップ API

```swift
// MidiOutputService
warmUpPreviewEngineIfNeeded()  // outputRoute == .tinyPiano のとき ensureTinyPianoReady()
```

- 同期で `TinyToneEngine.start()` まで返る（数十 ms 程度）。**0.5 秒待ってから UI 遷移するわけではない**。
- 「はじめる」押下時にオンボーディング画面上でエンジンが立ち上がるため、短い起動ノイズが聞こえることがある（後述ゲートの対象外クリックもあり得る）。

## 出力ゲート（0.5 秒）

`TinyToneEngine` / `RenderState` の起動直後ポップ対策。

- **いつ**: `AVAudioEngine` が **停止 → 起動** する直前の **1 回だけ**（`stabilizeBeforeGraphStart`）。
- **長さ**: `sampleRate * 0.5` サンプル ≒ **500 ms**（48 kHz で 24,000 サンプル）。
- **形状**: ゲイン 0 → 1 の **二乗カーブ**（`advanceOutputGate`、サンプルごとに 1 ステップ）。
- **注意**: `start()` が既に動いている状態では **ゲートも `silenceImmediately` も呼ばない**。以前は毎 `noteOn` で `start()` していたためアタックが潰れた；修正済み。

パッチ変更時（`loadSoundPatch`）は `patchChange` event → render callback 冒頭で **パッチ差し替え + 無音化**（ゲートなし）。HOLD 中の voice が新パッチで一瞬だけ鳴るのを避ける。

## パッチの載せ方

| API | エンジン未起動 | エンジン起動中 |
|-----|----------------|----------------|
| `prepareSoundPatch` | パッチだけメモリに保持 | `renderState.updatePatch` |
| `loadSoundPatch` | 同上 + 変更後 `silenceImmediately` | 同上 |
| `applyPreviewSoundPreset(..., startEngineIfNeeded: false)` | 起動時 bootstrap 用 | — |
| `applyPreviewSoundPreset(..., startEngineIfNeeded: true)` | — | `loadSoundPatch` 相当 |

設定でプリセットを変えたときは、**エンジンが既に動いている場合だけ** `startEngineIfNeeded: true`（`selectPreviewSoundPreset`）。

次バージョン以降の App Group 共有案は [TINYTONE_APP_GROUP_SHARING.md](TINYTONE_APP_GROUP_SHARING.md) を参照。現行の TinyTone LOAD / EXPORT と JPad JSON LOAD は残し、共有音色は追加候補として扱う。

## ファクトリプリセット

- 同梱: `JPad/Resources/FactoryPresets/`（`manifest.json` の順がプルダウン順）。
- 読み込み: `TinyToneFactoryPresets`。
- 既定 ID: `PreviewSoundPresetIDs.tinyTone`（`factory:TinyTone`）。
- 2 番目の **TinyPiano** は別 JSON（リバーブ等が異なる）。アップデート時の自動選択は **TinyTone** のみ。

## UserDefaults キー

| キー | 用途 |
|------|------|
| `selectedMidiOutputRoute` | `tinyPiano` / `garageBand` / `device` |
| `previewSoundSelectedPresetID` | 例 `factory:TinyTone`, `custom:imported` |
| `previewSoundCustomPatchData` | LOAD した JSON |
| `previewSoundPatchData` | **レガシー**（移行後削除） |

## バックグラウンド

`handleAppResignActive`（内蔵ルート時）:

1. `shouldResumePreviewEngineAfterBackground` = 当時 `isEngineRunning`
2. エンジン `stop` + `clearInternalPreviewReady`

復帰時はフラグが true のときだけ `ensureTinyPianoReady()`。

## 触るときの注意（トリッキーな点）

1. **`start()` に `stabilizeAfterGraphStart` を毎回入れない** … 全ノートのアタックが死ぬ。
2. **起動時に `ensureTinyPianoReady` を安易に呼ばない** … コールドスタートでスピーカーからポップが出る。
3. **ウォームアップを `onAppear`（設定を開いた瞬間）に戻さない** … 同上。TEST NOTE は押下時に `setTestNoteEnabled` 内で起動する。
4. **出力ゲートは「聞こえない時間」≠ UI がブロックされる時間** … ゲートはオーディオスレッド上の 500 ms。ボタン押下は即座に画面遷移する。
5. **コード上の `tinyPiano` と製品名 TinyTone** … リネームは UserDefaults 互換のため未実施。表示は L10n で TinyTone。
6. **DSP の正本** … `TinyToneTuner` と揃える。JPad だけ簡略エンジンに戻さない。
7. **Debug 専用の二重経路を復活させない** … 本線は常に `TinyToneEngine` + ファクトリ／LOAD プリセット。

## 未対応の追加対策

- JPad 側で TinyTone 選択時に silent warm-up をより早いタイミングへ移す。PAD 初回操作と `AVAudioEngine` 初回起動を分離するため。
- `buildRuntimePatch()` の係数計算をパッチ更新時に事前計算し、render callback 内の `pow()` / `ceil()` / snapshot 構築を減らす。

## 設定画面へ入るときの HOLD ノイズ対策

HOLD 中に歯車から設定画面へ入る場合は、`MainViewModel.presentSettings()` 経由で先に RESET 相当の `sendAllNotesOff()` を実行し、180ms 後に sheet を表示する。HOLD の持続音を残したまま sheet を生成すると、実機で短いノイズが再現したため。

## 関連ファイル

- `JPad/Services/Audio/TinyToneEngine.swift` … グラフ・ゲート・レンダリング
- `JPad/Services/Midi/MidiOutputService.swift` … ルート・ウォームアップ・プリセット
- `JPad/Features/Onboarding/OnboardingView.swift` … はじめる → `warmUpPreviewEngineIfNeeded`
- `JPad/Features/MidiRouting/MidiSettingsView.swift` … 設定 close → ウォームアップ
- `JPad/App/JChordApp.swift` … セッションのみ / 復帰時再開
