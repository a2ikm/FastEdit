# マルチカーソル・矩形選択

矩形選択・マルチカーソル編集機能の設計と実装の記録。

## 操作方法

| 操作 | 説明 |
|------|------|
| Option + ドラッグ | 矩形選択（連続行の同一列にカーソル配置） |
| Ctrl + Shift + ↑ | カーソルの上の行にカーソルを追加 |
| Ctrl + Shift + ↓ | カーソルの下の行にカーソルを追加 |
| 文字入力 | 全カーソル位置に同一テキストを挿入 |
| Delete / Backspace | 全カーソル位置で削除 |
| 矢印キー | 全カーソルを同時移動 |
| Esc / 通常クリック | マルチカーソルを解除 |

## 実装構成

すべて `EditorTextView`（NSTextView サブクラス）に実装。

### 状態管理

- `insertionLocations: [Int]` — 追加カーソルの文字インデックス配列（プライマリ選択は NSTextView 標準の `selectedRange` で管理）
- `selectionOrigins: [Int]` — 選択範囲の原点（将来の Shift+移動での選択拡張用に予約）
- `isPerformingRectangularSelection: Bool` — Option+ドラッグ中フラグ

### カーソル表示

`NSTextInsertionIndicator` を使用。`insertionLocations` の `didSet` で `updateInsertionIndicators()` が発火し、各位置にインジケーターを配置する。ウィンドウのキー状態変化時に `displayMode` を切り替える。

### 矩形選択の処理フロー

1. `mouseDown(with:)` — Option キー検出で `isPerformingRectangularSelection = true`、マウス座標を記録
2. `setSelectedRanges(_:affinity:stillSelecting:)` — 矩形選択中なら `computeInsertionLocations()` で各行の列位置を計算
3. `computeInsertionLocations()` — マウスダウン座標の X 位置を基準に、候補範囲に含まれる各行の対応する文字インデックスを算出
4. `characterIndex(atXPosition:inLineStartingAt:)` — グリフの左右端との距離比較で最も近い文字位置を特定

### テキスト編集

複数位置への編集は逆順（後ろから前）に処理し、前方のインデックスがずれないようにする。`undoManager` の `beginUndoGrouping` / `endUndoGrouping` で1回の Undo 操作にまとめる。

### Ctrl+Shift+Up/Down

`keyDown(with:)` でキーコードと修飾フラグを検出し、`selectColumnUp(_:)` / `selectColumnDown(_:)` を呼び出す。macOS では矢印キーに `.function` フラグが付くため、`flags.contains(.control) && flags.contains(.shift)` で判定する（完全一致ではなく包含判定）。Edit メニューにも項目を配置（キーボードショートカットはコード側で処理）。

## 設計判断

- **NSTextView サブクラス方式を採用** — マウスイベント・テキスト入力・キーイベントのオーバーライドが必要なため、プロトコル拡張ではなくサブクラスで実装。FastEdit は単一の TextView クラスしかないためサブクラスで十分
- **プライマリ選択は NSTextView 標準に委譲** — `selectedRange` は NSTextView の標準機能をそのまま使い、追加カーソルのみ `insertionLocations` で管理

## 未実装（将来追加候補）

- Command + クリック/ドラッグ（任意位置へのカーソル追加・削除）
- 矩形コピー＆ペースト（`.multipleTextSelection` Pasteboard 連携）
- Shift + カーソル移動での選択範囲拡張
- IME 入力時の自動単一カーソル復帰
