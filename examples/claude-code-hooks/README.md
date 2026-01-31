# Claude Code Hooks 連携

Claude Code がタスク完了、入力待ち、質問時に pyokotify で通知します。

## イベント

| イベント | トリガー |
|---------|---------|
| `Stop` | タスク完了時 |
| `Notification` | 権限が必要 / 入力待ち |
| `PreToolUse` (AskUserQuestion) | Claude が質問したとき |

## セットアップ

1. pyokotify を `~/.local/bin/` にインストール
2. ファイルを `~/.claude/hooks/` にコピー
3. hooks 設定を `~/.claude/settings.json` にマージ
4. キャラクター画像を配置

```console
cp notify.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/notify.sh
cp /path/to/your/character.png ~/.claude/hooks/character.png
```

## 設定

`notify.sh` を編集してカスタマイズ:

| 変数 | 説明 |
|------|------|
| `PYOKOTIFY` | pyokotify バイナリのパス |
| `PYOKOTIFY_IMAGE` | キャラクター画像のパス |
| `PYOKOTIFY_OPTS` | オプション（表示時間、高さなど） |

## カスタマイズ

`notify.sh` のメッセージを変更:

```bash
# 例: ずんだもん風
MESSAGE="$PROJECT_INFO 完了なのだ！"
MESSAGE="$PROJECT_INFO 質問があるのだ！"
MESSAGE="$PROJECT_INFO 許可が必要なのだ！"
```
