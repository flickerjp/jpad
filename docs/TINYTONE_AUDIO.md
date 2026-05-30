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
| **「JPad をはじめる」**（`OnboardingView.finishOnboarding`） | `completeWelcomeHandoff()`。TEST NOTE停止 → 必要なら300ms待ち → silent prime |
| **設定シートを閉じる**（`MidiSettingsView.onDisappear`） | `setTestNoteEnabled(false)` → `sendAllNotesOff()` → セッション準備のみ。**非同期 warm-up はしない** |
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
- 設定シートを閉じるタイミングでは呼ばない。シート dismiss 直後に非同期 warm-up とパッド発音が重なると、実機で数回だけノイズが出てから収まる症状が再現したため。

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
2. `sendAllNotesOff()` で発音を止める
3. エンジン graph は即 teardown しない

`UIBackgroundModes audio` は **GarageBand 向け仮想 MIDI ソース作成のために必要**。この key を外すと、GarageBand をバックグラウンドに入れた状態で `MIDISourceCreate` / `MIDISourceCreateWithProtocol` が `kMIDINotPermitted` (`-10844`) を返し、設定画面診断が `client=yes source=- live=no visible=no err=-10844` になった。`Info.plist` に `UIBackgroundModes` → `audio` を戻すと `source=JPad live=yes visible=yes` になり、GarageBand で発音できることを確認済み。

この background mode は **JPad がバックグラウンドで鳴り続けるためではなく、GarageBand / CoreMIDI 連携で仮想 MIDI ソースを維持するため** のもの。すでに同構成で App Review を通過して公開済みのため、この用途自体が直ちに審査リスクになるとは考えにくい。ただし、審査向け説明ではノイズ対策や審査回避ではなく「GarageBand へ演奏 MIDI を送るための audio background mode」と説明する。内蔵 TinyTone をバックグラウンド音源として鳴らし続ける仕様にはしない。

App Review 上の注意点:

- `audio` background mode を入れる理由は、ノイズ対策や審査回避ではなく GarageBand 連携のため。
- ユーザー操作なしでバックグラウンド再生を継続する機能として説明しない。
- すでに公開版で審査通過済みの構成なので、同じ用途・同じ実装方針を維持する限り追加リスクは低い。
- 審査で質問された場合は「JPad のパッド演奏を GarageBand へ CoreMIDI で送るため、仮想 MIDI source を維持する必要がある」と説明する。

ただし、`sendAllNotesOff()` 直後に `previewEngine.stop()` / graph teardown まで行うと、iOS の suspend と重なって render thread が無音化を消化する前に短いポップが戻る可能性があったため、即停止は避ける。

復帰時はフラグが true のときだけ `ensureTinyPianoReady()`。

## GarageBand 仮想 MIDI 診断

設定画面で `GarageBand` ルートを選ぶと、切り分け用に以下のような診断文字列を表示する。

```text
GB client=yes source=JPad live=yes visible=yes pref=packet used=packet packet=ok event=- err=ok last=Note On 48 ch1 vel 100
```

| 表示 | 意味 |
|------|------|
| `client` | `MIDIClientCreateWithBlock` が成功しているか |
| `source` / `live` | JPad 仮想 MIDI ソースが作成され、生きているか |
| `visible` | `MIDIGetNumberOfSources()` から `JPad` ソースが見えているか |
| `packet` / `event` / `used` | `MIDIReceived` / `MIDIReceivedEventList` の送信結果と成功方式 |
| `err` | 仮想ソース生成時の直近 `OSStatus` |
| `last` | 最後に送信した MIDI 内容 |

`client=yes source=- live=no visible=no err=-10844` は `kMIDINotPermitted` で、まず `Info.plist` の `UIBackgroundModes audio` を確認する。`source=JPad live=yes visible=yes` まで進んで音が出ない場合は、GarageBand 側の入力対象、チャンネル、Run in Background 設定を疑う。

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

## 設定画面遷移のノイズ対策

実機で「パッド発音 → 設定画面」と「設定画面 → パッドへ戻って発音」でノイズが再発した。更新済みインストール機で再現し、数回発音すると収まる傾向があった。

現在の対策:

1. `MainViewModel.presentSettings()` は HOLD 中だけでなく、設定を開くたびに RESET 相当の `sendAllNotesOff()` を実行する。
2. `sendAllNotesOff()` 後、300ms 待ってから sheet を表示する。
3. `MidiSettingsView.onDisappear` は `setTestNoteEnabled(false)`、`sendAllNotesOff()`、`preparePreviewAudioIfNeeded()` のみにする。
4. 設定 dismiss 直後の `warmUpPreviewEngineIfNeeded()` は禁止。戻った直後のユーザー発音と silent prime が競合して、数回だけ出るノイズの原因になり得る。

旧対策は HOLD 中のみの遅延だったが、通常発音直後に設定を開く経路では効いていなかった。設定画面は音声状態の境界として扱い、常に一度リセットしてから表示する。

## 関連ファイル

- `JPad/Services/Audio/TinyToneEngine.swift` … グラフ・ゲート・レンダリング
- `JPad/Services/Midi/MidiOutputService.swift` … ルート・ウォームアップ・プリセット
- `JPad/Features/Onboarding/OnboardingView.swift` … はじめる → `completeWelcomeHandoff`
- `JPad/Features/MidiRouting/MidiSettingsView.swift` … 設定 close → 発音停止 + セッション準備のみ
- `JPad/App/JPadApp.swift` … セッションのみ / 復帰時再開
