# リポジトリ引き継ぎ

## 手動メモ（次の作業者へ）

- **仕様・UI の正本:** [docs/README.md](README.md) → [PRESET_LIBRARY.md](PRESET_LIBRARY.md) / [UI_DESIGN.md](UI_DESIGN.md)
- **内蔵 PAD OUT（TinyTone）:** [TINYTONE_AUDIO.md](TINYTONE_AUDIO.md) — Debug/Release 共通の本線。旧 TinyPiano エンジン・デバッグ専用分岐はなし
- **現行ビルド:** `1.0.02 (108)` · `sheet-chrome-v1`（設定フッターで確認）
- **シート外周白枠:** iPhone（MAX 含む）は非表示、iPad mini 以上のみ（`JChordDeviceTraits`）
- 次にやること・未解決・注意点をここに書いてください。

## 自動ログ（コミットの都度追記）

以下は **Git `post-commit`**（`~/.githooks` + `core.hooksPath`）および **Cursor ユーザー `hooks.json` の `afterShellExecution`** で追記されます。  
同じコミット SHA では二重に入りません。

### グローバルセットアップ

初回のみ: リポジトリ `jcue1.2` などから `./scripts/install-handover-hooks-global.sh` を実行してください（`~/.cursor/hooks/` と `~/.githooks` に配置し、`git config --global core.hooksPath` を設定します）。

### 同期コミット

通常コミット後に `docs/HANDOVER.md` を更新し、続けて **`chore: sync handover log`** で取り込みます。止めたい場合は `HANDOVER_NO_AUTO_SYNC=1` を設定してください。


<!-- handover:auto:a0d9ef1fe5f6955be9a189c3570baeb8685362ce -->
### 2026-05-17 12:45:22 +0900 — `a0d9ef1` — main

**件名:** Initial commit: JChord MIDI pad app with preset loading and GarageBand routing.

**作者:** tone <tone@tonem4max.local>

**参照:** `git show a0d9ef1` / `git log -1 a0d9ef1`


<!-- handover:auto:ff512aba86f22a3fb57175ff4651bc67842a9efb -->
### 2026-05-17 20:28:51 +0900 — `ff512ab` — main

**件名:** Add redesigned UI and simplify MIDI routing for stability.

**作者:** tone <tone@tonem4max.local>

**参照:** `git show ff512ab` / `git log -1 ff512ab`


<!-- handover:auto:496b3dc8ebebba44b15f888b9d218cbb242eeb47 -->
### 2026-05-17 22:31:22 +0900 — `496b3dc` — main

**件名:** Fix Input Notes keyboard capture and GarageBand MIDI output.

**作者:** tone <tone@tonem4max.local>

**参照:** `git show 496b3dc` / `git log -1 496b3dc`


<!-- handover:auto:1160da6bf21f0e388b15f8c1a1e6f77694800bb3 -->
### 2026-05-18 01:10:45 +0900 — `1160da6` — main

**件名:** Add onboarding, presets, and TestFlight config for JChord MIDI 1.0.01.

**作者:** tone <tone@tonem4max.local>

**参照:** `git show 1160da6` / `git log -1 1160da6`


<!-- handover:auto:71bba1fa7fb9730fe391af79ce42aacee643ce69 -->
### 2026-05-18 07:45:10 +0900 — `71bba1f` — main

**件名:** Improve pad editor UI and unify muted-orange accent controls.

**作者:** tone <tone@tonem4max.local>

**参照:** `git show 71bba1f` / `git log -1 71bba1f`


<!-- handover:auto:ebcc7fbcb6ebbeb6f50aa47f88596c3e1ebda946 -->
### 2026-05-18 15:12:51 +0900 — `ebcc7fb` — issue/1-store-app-icon

**件名:** Rotate app icon 90° clockwise for App Store.

**作者:** tone <tone@tonem4max.local>

**参照:** `git show ebcc7fb` / `git log -1 ebcc7fb`


<!-- handover:auto:d607270a554b7a8c6ca3ea2bf218915b9c984986 -->
### 2026-05-18 15:19:30 +0900 — `d607270` — issue/1-store-app-icon

**件名:** Bump version to 1.0.02 (102) for TestFlight.

**作者:** tone <tone@tonem4max.local>

**参照:** `git show d607270` / `git log -1 d607270`


<!-- handover:auto:1d90654930b01ce21fe44ce1b16a27dc4ead3424 -->
### 2026-05-18 15:59:59 +0900 — `1d90654` — issue/2-ui-revision

**件名:** Apply muted-orange pad palette based on MIDI OUT state.

**作者:** tone <tone@tonem4max.local>

**参照:** `git show 1d90654` / `git log -1 1d90654`


<!-- handover:auto:41a3b45c71729ee19e43f986383f60e671b04e94 -->
### 2026-05-18 16:07:27 +0900 — `41a3b45` — issue/2-ui-revision

**件名:** Fix main pad colors: gray idle without OUT, bright orange when pressed.

**作者:** tone <tone@tonem4max.local>

**参照:** `git show 41a3b45` / `git log -1 41a3b45`


<!-- handover:auto:1f10ec487657a6411d8248df40de08716c75fb9e -->
### 2026-05-18 16:57:42 +0900 — `1f10ec4` — issue/2-ui-revision

**件名:** Revert all-pad orange tint; add MIDI OUT status dot by settings gear.

**作者:** tone <tone@tonem4max.local>

**参照:** `git show 1f10ec4` / `git log -1 1f10ec4`


<!-- handover:auto:9e66a226408e85b5c760c7c57cac51ce59af79dc -->
### 2026-05-18 17:02:43 +0900 — `9e66a22` — issue/2-ui-revision

**件名:** Merge origin/main into issue/2-ui-revision

**作者:** tone <tone@tonem4max.local>

**参照:** `git show 9e66a22` / `git log -1 9e66a22`


<!-- handover:auto:a06ef9994fba088ff0b236d207bc8c5d1bc2851a -->
### 2026-05-18 22:08:13 +0900 — `a06ef99` — main

**件名:** Add jcstore demo static site under web/jcstore.

**作者:** tone <tone@tonem4max.local>

**参照:** `git show a06ef99` / `git log -1 a06ef99`


<!-- handover:auto:0bdba9866d45c8f46f37ca52d03b2fa2d106aca1 -->
### 2026-05-18 22:25:54 +0900 — `0bdba98` — main

**件名:** Add preset library, jcstore import, and pad editor improvements.

**作者:** tone <tone@tonem4max.local>

**参照:** `git show 0bdba98` / `git log -1 0bdba98`


<!-- handover:auto:cc0a482c53239272ec35757dcc967f9910f341b6 -->
### 2026-05-18 22:35:11 +0900 — `cc0a482` — main

**件名:** Fix preset deletion re-seed, inline jcstore in picker, disable share/import UI.

**作者:** tone <tone@tonem4max.local>

**参照:** `git show cc0a482` / `git log -1 cc0a482`


<!-- handover:auto:fb1718c1715b39a38f5a1273523e3509ff516b78 -->
### 2026-05-18 23:37:31 +0900 — `fb1718c` — main

**件名:** Refine preset picker UX, blank sets, rename, and store import rules.

**作者:** tone <tone@tonem4max.local>

**参照:** `git show fb1718c` / `git log -1 fb1718c`


<!-- handover:auto:d075853543ee28c533114b29995c00fe79e13ed7 -->
### 2026-05-19 00:45:32 +0900 — `d075853` — main

**件名:** Polish preset library UX, City Pops voicings, and iPad layout.

**作者:** tone <tone@tonem4max.local>

**参照:** `git show d075853` / `git log -1 d075853`


<!-- handover:auto:2e0c538b3d7e7c6374f646b445010bb7fe82650c -->
### 2026-05-19 09:41:21 +0900 — `2e0c538` — main

**件名:** Add preset rotation, MY SETS reordering, and related UX polish.

**作者:** tone <tone@tonem4max.local>

**参照:** `git show 2e0c538` / `git log -1 2e0c538`


<!-- handover:auto:6142c77f237761d6f18448eed0424a12bfc5453b -->
### 2026-05-19 09:52:45 +0900 — `6142c77` — main

**件名:** Remove starter reseed UI and bump TestFlight build to 103.

**作者:** tone <tone@tonem4max.local>

**参照:** `git show 6142c77` / `git log -1 6142c77`


<!-- handover:auto:3f626007735b6dc11c241b92afe97ddbec772288 -->
### 2026-05-19 18:37:47 +0900 — `3f62600` — main

**件名:** Rebrand to JPad with Pro subscriptions, preset sharing, and store overhaul.

**作者:** tone <tone@tonem4max.local>

**参照:** `git show 3f62600` / `git log -1 3f62600`


<!-- handover:auto:5a9ec4dbaa341e348f9ca8e09226caf5869463a9 -->
### 2026-05-19 18:38:44 +0900 — `5a9ec4d` — main

**件名:** Update jcstore web for JPad branding and sync manifest paths.

**作者:** tone <tone@tonem4max.local>

**参照:** `git show 5a9ec4d` / `git log -1 5a9ec4d`


<!-- handover:auto:2df4dd4c87ac9c4d34a46969cad8f32960b02617 -->
### 2026-05-20 08:17:23 +0900 — `2df4dd4` — main

**件名:** Tone down Input Notes popup panel to a 5% white blend.

**作者:** tone <tone@tonem4max.local>

**参照:** `git show 2df4dd4` / `git log -1 2df4dd4`


<!-- handover:auto:28f2819f4eeaad095919a20ef2d2bc20c6c6a092 -->
### 2026-05-20 08:18:21 +0900 — `28f2819` — main

**件名:** Widen Input Notes popup on large screens.

**作者:** tone <tone@tonem4max.local>

**参照:** `git show 28f2819` / `git log -1 28f2819`


<!-- handover:auto:d3a0eab9b820b37f08eb3f2a266d6b98bacd4ba6 -->
### 2026-05-20 08:24:15 +0900 — `d3a0eab` — main

**件名:** Apply popupPanel background to MIDI settings sheet outer frame.

**作者:** tone <tone@tonem4max.local>

**参照:** `git show d3a0eab` / `git log -1 d3a0eab`


<!-- handover:auto:52689401b4216f036c3f4f924f1ca7d04ea45656 -->
### 2026-05-20 08:26:48 +0900 — `5268940` — main

**件名:** Add white popup border to jChordPopupSheetBackground.

**作者:** tone <tone@tonem4max.local>

**参照:** `git show 5268940` / `git log -1 5268940`


<!-- handover:auto:6a60f455aba4c07c72bab0bc54cd9cd78794c4cb -->
### 2026-05-20 08:26:51 +0900 — `6a60f45` — main

**件名:** Align settings sheet corner radius with popup border.

**作者:** tone <tone@tonem4max.local>

**参照:** `git show 6a60f45` / `git log -1 6a60f45`


<!-- handover:auto:78a8363504ff14d8645fcf2a8fbf23450ee3836f -->
### 2026-05-20 08:50:00 +0900 — `78a8363` — main

**件名:** Add iPad-only sheet outer border and popup sheet background helpers.

**作者:** tone <tone@tonem4max.local>

**参照:** `git show 78a8363` / `git log -1 78a8363`


<!-- handover:auto:1e75c200f1792db104b250b32f86d00a5d2d5d75 -->
### 2026-05-20 08:50:03 +0900 — `1e75c20` — main

**件名:** Unify Presets sheet with popupPanel background on iPad.

**作者:** tone <tone@tonem4max.local>

**参照:** `git show 1e75c20` / `git log -1 1e75c20`


<!-- handover:auto:0f9245835fa28e23b9c53fd11ae511c8e3b07912 -->
### 2026-05-20 08:50:04 +0900 — `0f92458` — main

**件名:** Apply sheet chrome to settings and Pro upgrade sheets.

**作者:** tone <tone@tonem4max.local>

**参照:** `git show 0f92458` / `git log -1 0f92458`


<!-- handover:auto:0325bc3c56db98eb8d4377d2c490ee3d45588d39 -->
### 2026-05-20 08:50:05 +0900 — `0325bc3` — main

**件名:** Bump TestFlight build to 106 (sheet-chrome-v1).

**作者:** tone <tone@tonem4max.local>

**参照:** `git show 0325bc3` / `git log -1 0325bc3`


<!-- handover:auto:856f51d78372908208506288603c9026295fe995 -->
### 2026-05-20 18:54:01 +0900 — `856f51d` — main

**件名:** Update design and spec docs to match current JPad UI.

**作者:** tone <tone@tonem4max.local>

**参照:** `git show 856f51d` / `git log -1 856f51d`


<!-- handover:auto:4f840cb182e16613718d2c92f02cb3bb368bc04b -->
### 2026-05-20 22:00:38 +0900 — `4f840cb` — main

**件名:** Add PAD editor UI v1.1 key-input popup with in-popup label editing.

**作者:** tone <tone@tonem4max.local>

**参照:** `git show 4f840cb` / `git log -1 4f840cb`


<!-- handover:auto:251039c28bedbcc1504178faeab0e29405e35738 -->
### 2026-05-20 22:56:32 +0900 — `251039c` — main

**件名:** Refine PAD editor v1.1 MIDI input, popup UX, and EDIT pad preview.

**作者:** tone <tone@tonem4max.local>

**参照:** `git show 251039c` / `git log -1 251039c`


<!-- handover:auto:84919f3eb916c6e054c8ddb2106cdb0bc24c288b -->
### 2026-05-20 23:51:53 +0900 — `84919f3` — main

**件名:** Fix v1.1 key-input popup layout on iPad and bump build to 108.

**作者:** tone <tone@tonem4max.local>

**参照:** `git show 84919f3` / `git log -1 84919f3`


<!-- handover:auto:f8f6142e39f9e8b7ae30caed5aa56b351a5234ee -->
### 2026-05-21 23:51:11 +0900 — `f8f6142` — main

**件名:** Add FLASH performance pad style with scan animations and settings UX.

**作者:** tone <tone@tonem4max.local>

**参照:** `git show f8f6142` / `git log -1 f8f6142`


<!-- handover:auto:e4c98755e3bbae398eb564b15caa17270884cd8e -->
### 2026-05-22 00:39:20 +0900 — `e4c9875` — main

**件名:** Repeat FLASH on pad hold at half-note intervals and clarify NOTE INPUT ROOT display.

**作者:** tone <tone@tonem4max.local>

**参照:** `git show e4c9875` / `git log -1 e4c9875`


<!-- handover:auto:f57939ca64086200174bc77f6ba26033c76bb375 -->
### 2026-05-22 08:00:04 +0900 — `f57939c` — main

**件名:** Add TinyPiano built-in PAD OUT preview synth.

**作者:** tone <tone@tonem4max.local>

**参照:** `git show f57939c` / `git log -1 f57939c`


<!-- handover:auto:87beacb2b8b0a562dd518c16d1d91cbfc69ba390 -->
### 2026-05-22 08:29:07 +0900 — `87beacb` — main

**件名:** Tune TinyPiano polyphony, envelope, and output leveling.

**作者:** tone <tone@tonem4max.local>

**参照:** `git show 87beacb` / `git log -1 87beacb`


<!-- handover:auto:97efc90cca2daae02f9afecc91b4278bef061712 -->
### 2026-05-22 08:56:33 +0900 — `97efc90` — main

**件名:** Fix TinyPiano silence and bump TestFlight build to 109.

**作者:** tone <tone@tonem4max.local>

**参照:** `git show 97efc90` / `git log -1 97efc90`


<!-- handover:auto:d300ad24b9b7cfaae8c760a4c8eb5283e96b00b8 -->
### 2026-05-22 08:57:32 +0900 — `d300ad2` — main

**件名:** docs: note TestFlight build 109 in TESTFLIGHT.md

**作者:** tone <tone@tonem4max.local>

**参照:** `git show d300ad2` / `git log -1 d300ad2`


<!-- handover:auto:3e442dd4bb016763e3802fc94f41c395d0b47367 -->
### 2026-05-22 22:00:41 +0900 — `3e442dd` — main

**件名:** Refine MIDI routing UI and TinyTone

**作者:** tone <tone@tonem4max.local>

**参照:** `git show 3e442dd` / `git log -1 3e442dd`


<!-- handover:auto:09207e90be71b6ce4951e63d5b79e7df20685ddc -->
### 2026-05-23 07:03:47 +0900 — `09207e9` — main

**件名:** Add subscription legal links and clarify annual pricing for App Review.

**作者:** tone <tone@tonem4max.local>

**参照:** `git show 09207e9` / `git log -1 09207e9`


<!-- handover:auto:99bed93bb7e78ed7b14c9352b3f2b76b1ed9193a -->
### 2026-05-23 07:07:55 +0900 — `99bed93` — main

**件名:** Point privacy policy URL to Cloudflare clean path /privacy.

**作者:** tone <tone@tonem4max.local>

**参照:** `git show 99bed93` / `git log -1 99bed93`


<!-- handover:auto:8b8c3cef0db6a3cb3444a9967db457058e7304e3 -->
### 2026-05-23 17:21:05 +0900 — `8b8c3ce` — main

**件名:** Save TinyTone patch and bump build 111

**作者:** tone <tone@tonem4max.local>

**参照:** `git show 8b8c3ce` / `git log -1 8b8c3ce`


<!-- handover:auto:80bdf77c15a9b4067496911a28845782c45d6160 -->
### 2026-05-23 19:11:42 +0900 — `80bdf77` — main

**件名:** Add debug TinyToneEngine output route

**作者:** tone <tone@tonem4max.local>

**参照:** `git show 80bdf77` / `git log -1 80bdf77`


<!-- handover:auto:14552928aeed6bcef98fbbe9d399cde6fa7461ab -->
### 2026-05-23 21:21:21 +0900 — `1455292` — main

**件名:** Use TinyToneTuner DSP for built-in PAD OUT in all builds.

**作者:** tone <tone@tonem4max.local>

**参照:** `git show 1455292` / `git log -1 1455292`


<!-- handover:auto:15c96fadfb697a2971d896649f986e7f520e95ed -->
### 2026-05-23 21:21:28 +0900 — `15c96fa` — main

**件名:** Add settings UI to import TinyTone JSON patches into PAD OUT.

**作者:** tone <tone@tonem4max.local>

**参照:** `git show 15c96fa` / `git log -1 15c96fa`


<!-- handover:auto:55c2c5b941b352cd313d2ff4d67d3c2215912ab4 -->
### 2026-05-23 23:38:48 +0900 — `55c2c5b` — main

**件名:** Add TinyTone factory presets, deferred engine warm-up, and audio docs.

**作者:** tone <tone@tonem4max.local>

**参照:** `git show 55c2c5b` / `git log -1 55c2c5b`


<!-- handover:auto:80fcdd6f256ea1df297ac9d3129cedf63aaef490 -->
### 2026-05-23 23:41:35 +0900 — `80fcdd6` — main

**件名:** Document TinyTone as the sole production audio path.

**作者:** tone <tone@tonem4max.local>

**参照:** `git show 80fcdd6` / `git log -1 80fcdd6`


<!-- handover:auto:69713055508386286d6ba98081cb15ae53f4a2f5 -->
### 2026-05-24 09:01:59 +0900 — `6971305` — main

**件名:** Adopt TinyToneCore package for JPad internal preview synth.

**作者:** FLICKER <tonekeisuke@gmail.com>

**参照:** `git show 6971305` / `git log -1 6971305`


<!-- handover:auto:6225810f9c0b5bbf341711ae99fe272cadbfea9a -->
### 2026-05-24 12:20:07 +0900 — `6225810` — main

**件名:** Fix TinyToneCore SPM resolution for Xcode GUI builds.

**作者:** FLICKER <tonekeisuke@gmail.com>

**参照:** `git show 6225810` / `git log -1 6225810`


<!-- handover:auto:7dd711bc10c88ff763697fb16ca7f0c106ce91d3 -->
### 2026-05-24 16:03:23 +0900 — `7dd711b` — main

**件名:** Improve performance HOLD visuals and avoid settings audio pops.

**作者:** tone <tone@tonem4max.local>

**参照:** `git show 7dd711b` / `git log -1 7dd711b`


<!-- handover:auto:11a735b5e20b0e107426a69fa76de6341799d9ff -->
### 2026-05-24 17:03:01 +0900 — `11a735b` — main

**件名:** Tune performance idle and HOLD ripple animation.

**作者:** tone <tone@tonem4max.local>

**参照:** `git show 11a735b` / `git log -1 11a735b`


## TinyTone 初回ノイズ対策メモ — 2026-05-24

- 実施済み: `TinyToneCore/Sources/TinyToneCore/TinyToneAudioEngine.swift` で、起動直後の無音化と出力ゲート開始を `AVAudioEngine.start()` 後から `start()` 前へ移動。
- 実施済み: 実行中パッチ変更時の無音化は `requestSilence()` 経由にし、render callback 冒頭の `allNotesOff` event として処理。メインスレッドから render 中の voice / delay buffer を直接書き換えない。
- 追加実施: HOLD 中のプリセット変更で `patch` だけ先に差し替わると旧 voice が一瞬新パッチで鳴るため、`loadSoundPatch` は `patchChange` event として render callback 内で「パッチ差し替え + 無音化」を同時に処理する形へ変更。
- 追加実施: HOLD 中に歯車から設定画面へ入ると sheet 生成中に TinyTone の持続音が走り続けてノイズが出るため、`MainViewModel.presentSettings()` を追加。
- 追加実施: `sendPadOff` の自然リリース待ちでもノイズが残ったため、設定表示前に `fadeOutInternalPreviewForModalTransition()` で TinyTone 出力を 0 へ短くランプし、90ms 後に `sendAllNotesOff()`、音量復帰、sheet 表示の順に変更。
- 追加実施: `TinyToneAudioEngine.setPreviewLevel` は即時変更ではなく 60ms ramp に変更。初回 graph attach 時は保持済み level を即時反映する。
- 追加実施: 上記でも設定遷移時ノイズが残るため、検証用に歯車タップ時の HOLD 中処理を RESET 相当に変更。`presentSettings()` は先に `sendAllNotesOff()` を実行し、300ms 後に sheet を表示する。
- 未対応: JPad 側で TinyTone 選択中の silent warm-up をより早いタイミングへ移し、初回 PAD 操作と engine 初回起動を分離する。
- 未対応: `previewLevel` を `TinyToneAudioEngine` 側で renderState 作成前から保持し、初回 graph attach 時にも Expression 音量を反映する。
- 未対応: `buildRuntimePatch()` の係数計算をパッチ更新時へ寄せ、render callback 内の計算負荷を下げる。

<!-- handover:auto:17e0e9c3969f5bcee48880835e725c1c86f63ddd -->
### 2026-05-24 17:52:06 +0900 — `17e0e9c` — main

**件名:** Fix TinyTone settings transition noise

**作者:** tone <tone@tonem4max.local>

**参照:** `git show 17e0e9c` / `git log -1 17e0e9c`

<!-- handover:auto:2132107d075544dc1e12187f309ed4cf7dea153f -->
### 2026-05-24 18:08:43 +0900 — `2132107` — main

**件名:** Delay settings sheet after hold reset

**作者:** tone <tone@tonem4max.local>

**参照:** `git show 2132107` / `git log -1 2132107`


<!-- handover:auto:aa3580c3dcd52b63ba27433fe9f46a7acb5ee30e -->
### 2026-05-25 06:32:35 +0900 — `aa3580c` — cursor/jpad-portrait-1-0-16-build-116

**件名:** Lock JPad to portrait, require full screen on iPad, and bump to 1.0.16 (116).

**作者:** tone <tone@tonem4max.local>

**参照:** `git show aa3580c` / `git log -1 aa3580c`


<!-- handover:auto:cccfe572b52392775b509c6a251e4df5f81647cd -->
### 2026-05-25 06:49:01 +0900 — `cccfe57` — cursor/jpad-portrait-1-0-16-build-116

**件名:** Fix Key Input octave UX and release 1.0.17 (117).

**作者:** tone <tone@tonem4max.local>

**参照:** `git show cccfe57` / `git log -1 cccfe57`


<!-- handover:auto:a1fe6201418ddd819b358138bbae60f04634c769 -->
### 2026-05-25 19:29:16 +0900 — `a1fe620` — main

**件名:** Initial import from JChord as standalone JPad repository.

**作者:** FLICKER <tonekeisuke@gmail.com>

**参照:** `git show a1fe620` / `git log -1 a1fe620`


<!-- handover:auto:12b4f9b2b6a1239104f47416e75d6242f4b07122 -->
### 2026-05-25 19:33:39 +0900 — `12b4f9b` — main

**件名:** Keep JChord App Store identity: bundle ID and build 117.

**作者:** FLICKER <tonekeisuke@gmail.com>

**参照:** `git show 12b4f9b` / `git log -1 12b4f9b`


<!-- handover:auto:d81b8fe00c52165473ec3d0e425efc499f5c11d8 -->
### 2026-05-25 22:32:26 +0900 — `d81b8fe` — main

**件名:** Release 1.0.18 (118): TinyTone orange UI refresh and GarageBand help

**作者:** FLICKER <tonekeisuke@gmail.com>

**参照:** `git show d81b8fe` / `git log -1 d81b8fe`


<!-- handover:auto:0e885908ceb6ea1b57435ab562b20bdfc4bd73af -->
### 2026-05-25 23:04:54 +0900 — `0e88590` — main

**件名:** Fix welcome-to-main audio pops with NOTE reset delay and DSP priming

**作者:** FLICKER <tonekeisuke@gmail.com>

**参照:** `git show 0e88590` / `git log -1 0e88590`


<!-- handover:auto:6ccf3842e055013f325cc5c4b882af713eb4740b -->
### 2026-05-26 20:16:08 +0900 — `6ccf384` — main

**件名:** Refine JPad settings and App Group storage

**作者:** tone <tone@tonem4max.local>

**参照:** `git show 6ccf384` / `git log -1 6ccf384`

