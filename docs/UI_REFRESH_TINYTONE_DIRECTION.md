# JPad UI Refresh Direction - TinyTone Alignment

目的: 旧 JChord から JPad へ移行した後の大幅 UI 刷新方針を、Swift 実装前に固定する。Apple 側の build id は旧 JChord のまま継続し、以降 build 118 から JPad アプリとして更新する。

## 判断基準

- Web ページではなく、iOS アプリ本体の画面設計として扱う。
- TinyTone Tuner の密度、グレー面、10-12pt 系の小さめラベル、8px/pt 系の角丸、オレンジのアクセントを参照する。
- JPad の PAD は常時オレンジ化しない。待機状態はグレー、タップ/発音/強調状態のみオレンジを使う。
- 旧 JChord に戻せるよう、まずテーマトークンと視覚仕様の差し替えとして進める。機能ロジックや MIDI/TinyTone 音声経路は触らない。

## TinyTone から採るもの

| 項目 | TinyTone 側の特徴 | JPad への適用 |
|------|------------------|---------------|
| 背景 | `Color(white: 0.2)` の単色グレー | JPad も濃紺グラデーションをやめ、#333333 近辺の単色グレーへ寄せる |
| パネル | `Color(white: 0.24)`、白 12% 枠 | 設定、プリセット、編集パネルを #3D3D3D 近辺 + 白 12% 枠へ寄せる |
| 角丸 | 8pt が基準 | 大きなカード感を抑え、ボタン/チップ/パネルは 8-10pt を基準にする |
| フォント | ラベル 10-12pt、主要名 15pt | JPad のトップ/ボタン/補助ラベルを縮め、パッド名のみ可読性を優先する |
| オレンジ | `#F5AD52`, `#DB7A1A`, `#AD5705` | スライダーつまみ、選択、発音、HOLD active、警告的 CTA に限定して使う |

## JPad として残すもの

- PAD 待機色はグレー系のままにする。
- PAD タップ時、発音中、HOLD active は TinyTone オレンジを使う。
- PAD の主役は 12 個のタップ面なので、TinyTone よりパッド文字は大きく残す。
- MIDI 接続状態の緑/未接続の暖色表示は維持する。ただし全体の彩度は下げる。
- Pro/Unlock など購買 CTA は既存の視認性を保つが、背景面と角丸は TinyTone 寄せにする。

## カラー方針

| Token | 候補 | 用途 |
|-------|------|------|
| `appBackground` | `#333333` | メイン背景、シート背景 |
| `panelBackground` | `#3D3D3D` | 設定カード、プリセット行、編集面 |
| `panelBorder` | `rgba(255,255,255,0.12)` | パネル/ボタン通常枠 |
| `primaryLabel` | `rgba(255,255,255,0.90)` | 主要テキスト |
| `secondaryLabel` | `rgba(255,255,255,0.80)` | 補助テキスト |
| `padIdleTop` | `#4A4A4A` | PAD 待機グラデーション上 |
| `padIdleBottom` | `#2D2D2D` | PAD 待機グラデーション下 |
| `accentLight` | `#F5AD52` | オレンジ上、値表示、スライダーつまみ |
| `accentMid` | `#DB7A1A` | 選択/発音の中心色 |
| `accentDeep` | `#AD5705` | オレンジ下、押下深度 |

## FLASH 方針

現行の Launchpad 系 5 色は彩度が高く、TinyTone の解釈から外れている。刷新後は「TinyTone のグレー UI の中で見える控えめな発光」として再定義する。

| 状態 | 方針 |
|------|------|
| Tap flash | TinyTone オレンジの短い発光。PAD 自体はオレンジ化するが、余韻は短くする |
| Hold pulse | オレンジをゆっくり明滅。背景全体や周辺 PAD まで派手に広げない |
| Performance flash | 赤/黄/青/緑/紫の Launchpad 色から、Amber / Cool Gray / Soft Blue / Soft Green / Soft Violet の低彩度セットへ変更 |
| Reduce Motion | 行ごとの色分けは残すが、発光量を小さくして通常 PAD のグレー面を優先 |

## 実装順

1. `JChordTheme` に TinyTone 寄せのトークンを追加し、既存トークン名のまま段階的に差し替える。
2. メイン背景、パネル、ボタン、スライダー、PAD 待機状態を先に変更する。
3. FLASH / performance palette を低彩度化する。
4. 設定、Preset、Pad Editor のシート chrome を同じ 8-10pt 角丸・グレー面へ揃える。
5. build 118 向けに実機スクリーンショットで iPhone / iPad の文字詰まりを確認する。

## 確認用 HTML

カラー確認用の静的 HTML は `mockups/jpad-tinytone-color-direction.html`。アプリ実装ではなく、SwiftUI へ移す前の見た目確認だけに使う。
