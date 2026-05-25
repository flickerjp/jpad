# TestFlight 初回アップロード手順（JPad / JChord）

初めて TestFlight に載せるときのチェックリストです。**初回は Xcode の GUI からアップロードするのがいちばん確実**です。

アプリ内表示名・設定フッターは **JPad**。Xcode ターゲット名は `JChord`、製品名 `JPad`（`project.yml` の `PRODUCT_NAME`）。

## 事前に必要なもの

| 項目 | 状態の確認 |
|------|------------|
| [Apple Developer Program](https://developer.apple.com/programs/)（年 $99） | 加入済みか |
| App Store Connect へのアクセス | [appstoreconnect.apple.com](https://appstoreconnect.apple.com) にログインできるか |
| Mac の Xcode | 署名用（Team: `G942ZU3CGC` / KEISUKE TONE） |
| **Bundle ID** | 下記「要変更」を必ず読む |

## Bundle ID（本番）

**`com.flickerproduct.jchord`**

1. [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/identifiers/list) で上記 **App ID** が登録済みか確認
2. App Store Connect で新規 App 作成時も **同じ Bundle ID** を選ぶ
3. `project.yml` 変更後は `xcodegen generate` で Xcode プロジェクトを再生成

## バージョン

| 項目 | 値 |
|------|-----|
| 表示バージョン（Marketing） | `1.0.02` |
| ビルド番号（Build） | **`109`**（TestFlight を上げるたびに +1） |

`project.yml` の `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` で管理。`xcodegen generate` 後に `JPad.xcodeproj` と一致させる。

**ビルド確認:** 設定画面フッターに `JPad 1.0.02 (109) · perf-pads-v1` のように表示（`AppBuildIdentity`）。`layoutRevision` を変えたリリースではここも更新する。

### サブスクリプション（JChord Yearly）

| 項目 | 値 |
|------|-----|
| Product ID | `com.jflickeys.jchord.pro.yearly` |
| 種類 | 自動更新サブスクリプション（年額） |
| 英語（米国）表示名 | **JChord Yearly**（Connect 上。アプリ内購入画面タイトルは **JPad Pro**） |
| アプリ名 | **JChord MIDI**（Connect）。ホーム画面は **JPad** |

詳細: [APP_STORE_SUBSCRIPTION.md](APP_STORE_SUBSCRIPTION.md)

**App Store Connect で要確認（リリース前チェックリスト）**

1. **サブスクリプション** → 上記 Product ID で年額プランを作成し、「提出準備完了」
2. **Paid Apps Agreement**（有料アプリ契約）が有効か
3. **税・銀行**情報が完了しているか
4. **Sandbox テスター**を追加し、実機で購入 → 復元 → SHARE/IMPORT が有効になるか
5. **App Privacy** で課金データの扱いを申告
6. 審査用 **スクリーンショット** に Pro 案内（購入シート）を含めるか検討
7. **レビューノート**に Sandbox アカウントと Pro 機能の確認手順を記載

購入完了後: 購入シートが閉じ、メイン画面に成功アラート → プリセットピッカーで **購入** ボタンが消え、SHARE/IMPORT が RESET/HOLD 同様の見た目で有効になる。

## 手順 A: Xcode から（推奨・初回）

### 1. App Store Connect で App を作る

1. **マイ App** → **＋** → **新規 App**
2. プラットフォーム: iOS  
3. 名前: `JChord MIDI`（App Store 表示名）  
4. プライマリ言語: 日本語または英語  
5. **Bundle ID**: `com.flickerproduct.jchord`  
6. SKU: 任意（例 `jchord-ios`）

### 2. Archive

1. Xcode で `JPad.xcodeproj` を開く（必要なら `xcodegen generate`）
2. 実行先: **Any iOS Device (arm64)**（シミュレータではない）
3. **Product → Archive**
4. 成功すると **Organizer** が開く

### 3. Upload

1. Organizer で該当 Archive を選ぶ → **Distribute App**
2. **App Store Connect** → **Upload**
3. 署名は **Automatically manage signing**（Distribution 証明書は Xcode が作成）
4. アップロード完了まで待つ（数分〜）

### 4. TestFlight

1. App Store Connect → 対象 App → **TestFlight**
2. ビルドが **処理中** → **準備完了** になるまで待つ（10〜30 分程度）
3. **輸出コンプライアンス** の質問に答える（MIDI アプリで独自暗号化がなければ多くは「いいえ」）
4. **内部テスト** または **外部テスト** にテスターを追加
5. テスターは iPhone に **TestFlight** アプリを入れ、招待メール / リンクからインストール

## 手順 B: コマンドライン（慣れてから）

Archive（実機用）:

```bash
cd /Users/tone/work/JChord
xcodegen generate
xcodebuild -scheme JChord -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath build/JChord.xcarchive archive
```

IPA  export & upload（Distribution 証明書が Keychain にある場合）:

```bash
xcodebuild -exportArchive \
  -archivePath build/JChord.xcarchive \
  -exportPath build/export \
  -exportOptionsPlist ExportOptions.plist

xcrun altool --upload-app -f build/export/JChord.ipa \
  --type ios --apiKey YOUR_KEY --apiIssuer YOUR_ISSUER
```

API キーは [App Store Connect → ユーザーとアクセス → キー](https://appstoreconnect.apple.com/access/api) で作成。

## アプリ審査前の確認（TestFlight でも推奨）

- [ ] `AppIcon-1024.png` が実アイコンになっている
- [ ] 初回オンボーディング・MIDI（GarageBand）が実機で動く
- [ ] 内蔵 **TinyTone**（PAD OUT）: 「JPad をはじめる」後のパッド発音、設定クローズ後の初回発音（起動ポップが許容範囲か）
- [ ] `UIBackgroundModes: audio`（仮想 MIDI 用）が意図どおり
- [ ] プライバシーポリシー URL（外部テストで必要になることが多い）

## よくあるエラー

| 現象 | 対処 |
|------|------|
| Archive の CodeSign 失敗 | Xcode で **Signing & Capabilities** を開き直す、Keychain の「開発者」を信頼、Mac 再起動 |
| `No profiles for ...` | Developer サイトで Bundle ID 登録 → Xcode **Download Manual Profiles** |
| アップロード後ビルドが出ない | メールの Export Compliance、App Store Connect の「不足コンプライアンス」 |
## このリポジトリの Team

- **Development Team**: `G942ZU3CGC`
- **Bundle ID**: `com.flickerproduct.jchord`
- 署名: Automatic
