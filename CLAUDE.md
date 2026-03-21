# FastEdit

macOS 向けプレーンテキストエディタ。

## アーキテクチャ

- **AppKit / NSDocument ベース** — 1ファイル1ウィンドウの Document-Based App
- **Storyboard** (`Main.storyboard`) でメニューバーとウィンドウ構成を定義
- Xcode の `PBXFileSystemSynchronizedRootGroup` を使用しており、`FastEdit/` ディレクトリにファイルを置けば自動的にプロジェクトに認識される
- `Info.plist` はプロジェクトルート直下に配置（`FastEdit/` 内に置くとリソースコピー対象になるため）
- `GENERATE_INFOPLIST_FILE = YES` と `INFOPLIST_FILE = Info.plist` を併用し、Document Type (`public.plain-text`) を登録

## 主要クラス

- `PlainTextDocument` — NSDocument サブクラス。テキストの読み書き、閉じる時の保存確認ダイアログ
- `ViewController` — NSTextView の管理。フォント設定、行折り返し切り替え、フォントサイズ変更。FindBarDelegate として検索バーと連携
- `FindBarViewController` — 検索・置換バーの UI とインタラクション。プログラマティックに構築（xib/storyboard 不使用）
- `RegexSearchEngine` — NSRegularExpression のラッパー。検索・置換ロジック
- `SelectionAdjustment` — 置換時のテキスト選択範囲調整。純粋関数として切り出し済み
- `AppDelegate` — 起動時に Untitled ドキュメントを開く

## 設計上の注意点

- **Swift Strict Concurrency** — `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` が有効。NSDocument の `autosavesInPlace`、`read(from:ofType:)`、`data(ofType:)` は `nonisolated` でオーバーライドが必要。`text` プロパティは `nonisolated(unsafe)` で宣言
- **Storyboard の initialViewController は未設定** — ウィンドウ生成は NSDocumentController に委譲。設定するとドキュメント未紐付のウィンドウが表示される
- **フォントは Osaka-Mono 14pt 固定**（将来的に設定画面から変更可能にする予定）
- **検索メニューは `findAction:` セレクタ** — Storyboard の Find サブメニューは `performFindPanelAction:` ではなく `findAction:` を使用。NSTextView の標準 Find Bar と競合しないようにするため
- **検索バーの配置** — ViewController のメインビュー上部に Find Bar を差し込み、ScrollView の top 制約を付け替える
- **マッチハイライト** — `NSLayoutManager.addTemporaryAttribute(.backgroundColor)` で全マッチを黄色、現在マッチをオレンジで表示。検索バー表示中はネイティブの選択ハイライトを無効化し、選択（半透明）・マッチ（黄）・現在の対象（オレンジ）の3層を temporary attributes で描画
- **検索バーのモード** — Cmd+F で検索モード（検索フィールドとトグルボタンのみ）、Cmd+Option+F で置換モード（置換フィールド・Replace/All・Next/Previous ボタンが追加表示）。Esc で閉じる
- **検索中にテキスト選択を変更しない** — 検索・置換の操作でテキストビューの選択範囲は変更しない。Next/Previous は置換モードでのみ表示され、置換対象のハイライトを移動するだけ

## ビルド

```
xcodebuild -scheme FastEdit -configuration Debug build
```

## テスト

```
xcodebuild test -scheme FastEdit -destination 'platform=macOS'
```

## 動作確認

実装が完了して動作確認できる状態になったら `bin/xcode-run` を実行して Xcode でデバッグビルド＆実行する。
