# pyokotify

画面の端からキャラクターがぴょこっと顔を出す macOS 通知アプリ

![demo](assets/demo.gif)

## 必要環境

- macOS 12.0以上
- Swift 5.9以上

※ macOS ネイティブ API (AppKit, NSWindow) を使用しているため、Linux / Windows では動作しません。

## インストール

### バイナリ

```console
curl -fsSL https://raw.githubusercontent.com/haryoiro/pyokotify/main/install.sh | bash
```

`~/.local/bin` にインストールされます。

**環境変数:**
- `PYOKOTIFY_QUIET=1` - 出力を抑制
- `PYOKOTIFY_DEBUG=1` - デバッグ出力を有効化

### ソースからビルド

```console
git clone https://github.com/haryoiro/pyokotify.git
cd pyokotify
swift build -c release
cp .build/release/pyokotify ~/.local/bin/
```

## 使い方

```console
pyokotify <画像パス>
pyokotify ~/Pictures/character.png
pyokotify ~/Pictures/character.png -t "タスク完了！"
```

## オプション

| オプション               | 説明                                       |
| ------------------------ | ------------------------------------------ |
| `-d, --duration <秒>`    | 表示時間（デフォルト: 3.0）                |
| `-a, --animation <秒>`   | アニメーション時間（デフォルト: 0.4）      |
| `-p, --peek <px>`        | 顔を出す高さ（デフォルト: 200）            |
| `-m, --margin <px>`      | 端からのマージン（デフォルト: 50）         |
| `-t, --text <メッセージ>` | 吹き出しでメッセージを表示                 |
| `-s, --sound <パス>`     | 通知時に音声を再生                         |
| `-c, --caller <アプリ>`  | クリック時に戻るアプリ                     |
| `--cwd <パス>`           | 作業ディレクトリ（特定ウィンドウにフォーカス）|
| `--no-click`             | クリック無効化（マウスイベントを通過）     |
| `--hooks`                | 標準入力から hooks JSON を読み取る         |
| `-r, --random`           | ランダム間隔で繰り返し表示                 |
| `--random-direction`     | ランダムな方向から出現（下/左/右）         |
| `--min <秒>`             | ランダムモードの最小間隔（デフォルト: 30） |
| `--max <秒>`             | ランダムモードの最大間隔（デフォルト: 120）|
| `-h, --help`             | ヘルプを表示                               |

## Claude Code との連携

pyokotify は [Claude Code](https://docs.anthropic.com/en/docs/claude-code) の hooks と連携できます。Claude が応答を待っているときに通知を受け取れます。

`--hooks` オプションを使うと、標準入力から hooks JSON を読み取り、cwd や caller が自動設定されます。

`~/.claude/settings.json` に追加:

```json
{
  "hooks": {
    "Stop": [{
      "matcher": "",
      "hooks": [{
        "type": "command",
        "command": "pyokotify ~/Pictures/character.png --hooks -t '[$dir:$branch] Done!'"
      }]
    }]
  }
}
```

テンプレート変数 (`-t` で使用可能): `$dir`, `$branch`, `$cwd`, `$event`, `$tool`

詳細は [examples/claude-code-hooks](examples/claude-code-hooks) を参照してください。

## 使用例

```console
# 5秒間、300pxの高さで表示
pyokotify ~/Pictures/character.png -d 5 -p 300

# 吹き出し付き
pyokotify ~/Pictures/character.png -t "ビルド成功！"

# ランダム間隔モード
pyokotify ~/Pictures/character.png -r --min 60 --max 300

# ランダムな方向から出現（下/左/右）
pyokotify ~/Pictures/character.png --random-direction
```

## SSH との連携

SSH 接続通知など、様々なシナリオで活用できます。

![ssh demo](assets/ssh_demo.gif)

## アクセシビリティ権限

`--cwd` オプションで特定のウィンドウにフォーカスするには、アクセシビリティ権限が必要です。

システム設定 > プライバシーとセキュリティ > アクセシビリティ > ターミナルアプリを追加

`--caller` オプションはこの権限なしで動作します。

## 対応エディター

`--cwd` オプションで正しいウィンドウにフォーカスできるエディター:

| エディター    | 備考                                         |
| ------------- | -------------------------------------------- |
| VSCode 系     | VSCode, Insiders, VSCodium, Cursor           |
| JetBrains 系  | IntelliJ, WebStorm, PyCharm, GoLand など全般 |

## ライセンス

MIT
