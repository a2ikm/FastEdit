# FastEdit

macOS 向けプレーンテキストエディタ。

## アーキテクチャ

- **AppKit / NSDocument ベース** — 1ファイル1ウィンドウの Document-Based App
- **Storyboard** (`Main.storyboard`) でメニューバーとウィンドウ構成を定義
- Xcode の `PBXFileSystemSynchronizedRootGroup` を使用しており、`FastEdit/` ディレクトリにファイルを置けば自動的にプロジェクトに認識される
- `Info.plist` はプロジェクトルート直下に配置（`FastEdit/` 内に置くとリソースコピー対象になるため）
- `GENERATE_INFOPLIST_FILE = YES` と `INFOPLIST_FILE = Info.plist` を併用し、Document Type (`public.plain-text`) を登録

## 主要クラス

- `PlainTextDocument` — NSDocument サブクラス。UTF-8 テキストの読み書き、閉じる時の保存確認ダイアログ
- `ViewController` — NSTextView の管理。フォント設定、行折り返し切り替え、フォントサイズ変更
- `AppDelegate` — 起動時に Untitled ドキュメントを開く

## 設計上の注意点

- **Swift Strict Concurrency** — `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` が有効。NSDocument の `autosavesInPlace`、`read(from:ofType:)`、`data(ofType:)` は `nonisolated` でオーバーライドが必要。`text` プロパティは `nonisolated(unsafe)` で宣言
- **autosavesInPlace は false** — 閉じる時のカスタム保存確認ダイアログ（Save / Don't Save の2択）を実装するため無効化
- **Storyboard の initialViewController は未設定** — ウィンドウ生成は NSDocumentController に委譲。設定するとドキュメント未紐付のウィンドウが表示される
- **フォントは Osaka-Mono 14pt 固定**（将来的に設定画面から変更可能にする予定）

## 将来の予定

- フォント設定機能
- 矩形選択・編集
- 正規表現による検索・置換（Oniguruma）

## ビルド

```
xcodebuild -scheme FastEdit -configuration Debug build
```
