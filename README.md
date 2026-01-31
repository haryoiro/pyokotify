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

```
-d, --duration <秒>        表示時間（デフォルト: 3.0）
-a, --animation <秒>       アニメーション時間（デフォルト: 0.4）
-p, --peek <px>            顔を出す高さ（デフォルト: 200）
-m, --margin <px>          端からのマージン（デフォルト: 50）
-t, --text <メッセージ>     吹き出しでメッセージを表示
-c, --caller <アプリ>       クリック時に戻るアプリ（TERM_PROGRAM 値）
    --cwd <パス>           このパスを含むウィンドウにフォーカス
    --no-click             クリック無効化（マウスイベントを通過）
-r, --random               ランダム間隔で繰り返し表示
    --random-direction     ランダムな方向から出現（下/左/右）
    --min <秒>             ランダムモードの最小間隔（デフォルト: 30）
    --max <秒>             ランダムモードの最大間隔（デフォルト: 120）
-h, --help                 ヘルプを表示
```

## Claude Code との連携

pyokotify は [Claude Code](https://docs.anthropic.com/en/docs/claude-code) の hooks と連携できます。Claude が応答を待っているときに通知を受け取れます。

Stop, Notification, AskUserQuestion イベントの完全なセットアップは [examples/claude-code-hooks](examples/claude-code-hooks) を参照してください。

簡単な例 - `~/.claude/settings.json` に追加:

```json
{
  "hooks": {
    "AskUserQuestion": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "pyokotify ~/Pictures/character.png -t 'Claudeから質問があるよ' -c $TERM_PROGRAM --cwd $PWD"
          }
        ]
      }
    ]
  }
}
```

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

## TERM_PROGRAM の値

| ターミナル   | 値               |
| ------------ | ---------------- |
| VSCode       | `vscode`         |
| iTerm2       | `iTerm.app`      |
| Terminal.app | `Apple_Terminal` |
| Ghostty      | `ghostty`        |
| Warp         | `WarpTerminal`   |
| Alacritty    | `Alacritty`      |
| kitty        | `kitty`          |

## ライセンス

MIT
