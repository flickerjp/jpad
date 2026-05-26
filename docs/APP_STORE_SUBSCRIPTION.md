# App Store Connect — JPad Pro（JChord Yearly）サブスクリプション

## 商品

| 項目 | 値 |
|------|-----|
| 種類 | 自動更新サブスクリプション（年額） |
| Product ID | `com.jflickeys.jchord.pro.yearly` |
| アプリ表示名（ホーム画面） | **JChord MIDI**（`INFOPLIST_KEY_CFBundleDisplayName`） |

## ローカリゼーション — 英語（アメリカ）

App Store Connect のサブスクリプション表示名・説明にコピーする用。

| フィールド | 文案（en-US） |
|------------|----------------|
| **サブスクリプション表示名** | JChord Yearly |
| **説明（例）** | Pro features for JChord MIDI: save up to 100 sets, duplicate sets, and share or import presets. |
| **アプリ名（文脈）** | JChord MIDI |

日本語ローカルは App Store Connect で別途追加。アプリ内文言は `pro.upgrade.*`（`Localizable.strings`）。

## アプリ内実装

- `ProPurchaseService.yearlyProductID` = 上記 Product ID
- `Transaction.currentEntitlements` で Pro 判定
- 購入画面: ナビタイトル **JPad Pro**（`pro.upgrade.title`）+ 価格行（StoreKit `displayPrice`）+ 自動更新の注記
- シート chrome: iPad のみ外周白枠（[UI_DESIGN.md](UI_DESIGN.md)）
- TinyTone App Group 共有音色の読み込みは JPad Pro ではなく無料側に置く方針（[TINYTONE_APP_GROUP_SHARING.md](TINYTONE_APP_GROUP_SHARING.md)）

## 旧 Product ID

`com.flickerproduct.jchord.pro`（非消耗型）は使用しない。移行が必要な場合は Entitlement 側で旧 ID を `productIDs` に追加する。
