# pyokotify

画面端からキャラクターがぴょこっと顔を出す macOS 用の通知アプリ。

![demo](assets/sample.png)

## 特徴

- キャラクターが画面端からぴょこっとアニメーションで登場
- 下・左・右からランダムな方向で出現可能
- 吹き出しでメッセージを表示（しっぽは自動でキャラクターを向く）
- クリックすると呼び出し元のアプリ/ウィンドウに戻る
- ランダム間隔でぴょこぴょこし続けるモード
- Dock に表示されない（邪魔にならない）

## 動作環境

> **⚠️ macOS 専用です**
>
> pyokotify は macOS のネイティブ API（AppKit、NSWindow 等）を使用しているため、**Linux や Windows では動作しません**。

- macOS 12.0 以上
- Swift 5.9 以上

## インストール

### ワンライナー（推奨）

```bash
curl -fsSL https://raw.githubusercontent.com/haryoiro/pyokotify/main/install.sh | bash
```

Intel Mac / Apple Silicon Mac の両方に対応した Universal Binary がインストールされます。

### ソースからビルド

```bash
# リポジトリをクローン
git clone https://github.com/haryoiro/pyokotify.git
cd pyokotify

# ビルド
swift build -c release

# パスを通す（任意）
cp .build/release/pyokotify /usr/local/bin/
```

### アクセシビリティ権限（オプション）

`--cwd` オプションで特定のウィンドウにフォーカスする機能を使う場合、アクセシビリティ権限が必要です。

1. **システム設定** → **プライバシーとセキュリティ** → **アクセシビリティ**
2. pyokotify を実行するアプリ（Terminal.app、iTerm2、VSCode など）を追加

権限がない場合でも `--caller` オプションによるアプリ切り替えは動作します。

## 使い方

### 基本

```bash
pyokotify <画像パス>
```

```bash
# 例: ずんだもんを表示
pyokotify ~/Pictures/zundamon.png
```

### オプション

| オプション | 説明 | デフォルト |
|-----------|------|-----------|
| `-d`, `--duration <秒>` | 表示時間 | 3.0秒 |
| `-a`, `--animation <秒>` | アニメーション時間 | 0.4秒 |
| `-p`, `--peek <px>` | 顔を出す高さ | 200px |
| `-m`, `--margin <px>` | 右端からのマージン（下から出現時） | 50px |
| `--no-click` | クリック無効化（マウスイベントを通過） | - |
| `-t`, `--text <メッセージ>` | 吹き出しでメッセージを表示 | - |
| `-c`, `--caller <アプリ>` | クリック時に戻るアプリ（TERM_PROGRAM値） | - |
| `--cwd <パス>` | 作業ディレクトリ（特定ウィンドウにフォーカス） | - |
| `-r`, `--random` | ランダム間隔でぴょこぴょこし続ける | - |
| `--random-direction` | ランダムな方向（下・左・右）から出現 | - |
| `--min <秒>` | ランダムモードの最小間隔 | 30秒 |
| `--max <秒>` | ランダムモードの最大間隔 | 120秒 |
| `--snooze <回数>` | クリックされなかった時の再通知回数 | 0（無効） |
| `--snooze-interval <秒>` | 再通知までの間隔 | 30秒 |
| `-h`, `--help` | ヘルプを表示 | - |

### 使用例

```bash
# 5秒間、300pxの高さで表示
pyokotify ~/Pictures/zundamon.png -d 5 -p 300

# 吹き出し付きで表示
pyokotify ~/Pictures/zundamon.png -t "タスク完了なのだ！"

# クリック無効で表示（マウスイベントを通過）
pyokotify ~/Pictures/zundamon.png --no-click

# 60〜300秒のランダム間隔でぴょこぴょこ
pyokotify ~/Pictures/zundamon.png -r --min 60 --max 300

# ランダムな方向（下・左・右）から出現
pyokotify ~/Pictures/zundamon.png --random-direction

# ランダム間隔＋ランダム方向
pyokotify ~/Pictures/zundamon.png -r --random-direction --min 60 --max 300

# スヌーズ機能：クリックされなかったら10秒後に再通知（最大3回）
pyokotify ~/Pictures/zundamon.png --snooze 3 --snooze-interval 10
```

## 活用例

### ビルド完了通知

```bash
swift build && pyokotify ~/Pictures/character.png -t "ビルド成功！"
```

### ポモドーロタイマー

```bash
sleep 1500 && pyokotify ~/Pictures/character.png -t "休憩の時間だよ！"
```

### 癒やしモード

```bash
pyokotify ~/Pictures/character.png -r --min 300 --max 600
```

### Claude Code hooks 連携

Claude Code の hooks 機能と連携して、タスク完了時に通知を表示できます。

#### 1. 通知スクリプトを作成

`~/.claude/hooks/notify.sh`:

```bash
#!/bin/bash
# Claude Code 通知スクリプト（pyokotify版）

INPUT=$(cat)

# ===== 設定 =====
PYOKOTIFY="$HOME/.local/bin/pyokotify"  # pyokotify のパス
PYOKOTIFY_IMAGE="$HOME/.claude/hooks/character.png"  # キャラクター画像

# 基本情報を取得
EVENT_NAME=$(echo "$INPUT" | jq -r '.hook_event_name // "Unknown"')
CWD=$(echo "$INPUT" | jq -r '.cwd // ""')
PROJECT_NAME=$(basename "$CWD")

# Git ブランチ（取得できれば）
GIT_BRANCH=$(timeout 1 git -C "$CWD" branch --show-current 2>/dev/null || echo "")

# プロジェクト情報
if [ -n "$GIT_BRANCH" ]; then
    PROJECT_INFO="[$PROJECT_NAME:$GIT_BRANCH]"
else
    PROJECT_INFO="[$PROJECT_NAME]"
fi

# イベントごとのメッセージ
case "$EVENT_NAME" in
  "Notification")
    NOTIFICATION_TYPE=$(echo "$INPUT" | jq -r '.notification_type // "unknown"')
    case "$NOTIFICATION_TYPE" in
      "permission_prompt")
        MESSAGE="$PROJECT_INFO 許可が必要！"
        ;;
      *)
        MESSAGE="$PROJECT_INFO 入力待ち！"
        ;;
    esac
    ;;
  "Stop")
    MESSAGE="$PROJECT_INFO 完了！"
    ;;
  *)
    MESSAGE="$PROJECT_INFO $EVENT_NAME"
    ;;
esac

# pyokotify 通知
if [ -f "$PYOKOTIFY" ] && [ -f "$PYOKOTIFY_IMAGE" ]; then
    PYOKOTIFY_OPTS="-t \"$MESSAGE\" -d 8 -p 200"

    # TERM_PROGRAM で呼び出し元アプリを指定
    if [ -n "$TERM_PROGRAM" ]; then
        PYOKOTIFY_OPTS="$PYOKOTIFY_OPTS --caller $TERM_PROGRAM"
    fi

    # CWD で特定ウィンドウにフォーカス
    if [ -n "$CWD" ]; then
        PYOKOTIFY_OPTS="$PYOKOTIFY_OPTS --cwd $CWD"
    fi

    eval "\"$PYOKOTIFY\" \"$PYOKOTIFY_IMAGE\" $PYOKOTIFY_OPTS" &
fi

exit 0
```

```bash
chmod +x ~/.claude/hooks/notify.sh
```

#### 2. Claude Code の設定

`~/.claude/settings.json`:

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/notify.sh"
          }
        ]
      }
    ],
    "Notification": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/notify.sh"
          }
        ]
      }
    ]
  }
}
```

#### 対応ターミナル

`--caller` オプションで指定できる `TERM_PROGRAM` の値：

| ターミナル | TERM_PROGRAM 値 |
|-----------|----------------|
| VSCode | `vscode` |
| iTerm2 | `iTerm.app` |
| Terminal.app | `Apple_Terminal` |
| Ghostty | `ghostty` |
| Warp | `WarpTerminal` |
| Alacritty | `Alacritty` |
| kitty | `kitty` |
| Hyper | `Hyper` |
| Tabby | `Tabby` |

## 注意点

### 画像について

- PNG、JPEG などの一般的な画像形式に対応
- 透過 PNG を使うとキャラクターが自然に表示されます
- 画像は自動的にアスペクト比を維持してリサイズされます

### ランダム方向について

- `--random-direction` は下・左・右の3方向からランダムに出現します
- 上からの出現は macOS の制限（メニューバー領域）により対応していません
- 左右から出現する場合、キャラクターは自動的に回転します（頭が画面内側を向く）

### クリック動作について

- キャラクターをクリックすると、呼び出し元のアプリに戻ります
- `--cwd` を指定すると、そのパスを含むウィンドウにフォーカスします（VSCode で複数ウィンドウを開いている場合に便利）
- `--no-click` を指定すると、マウスイベントが背後のウィンドウに通過します

## ライセンス

MIT
