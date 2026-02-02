# Claude Code Hooks 連携

Claude Code がタスク完了、入力待ち、質問時に pyokotify で通知します。

## イベント

| イベント                        | トリガー                   |
| ------------------------------- | -------------------------- |
| `Stop`                          | タスク完了時               |
| `Notification`                  | 権限が必要 / 入力待ち      |
| `PreToolUse` (AskUserQuestion)  | Claude が質問したとき      |

## セットアップ

1. pyokotify をインストール
2. キャラクター画像を配置
3. `settings.json` を `~/.claude/settings.json` にマージ

```console
cp /path/to/your/character.png ~/.claude/hooks/character.png
```

## 設定例

`--hooks` オプションを使うと、標準入力から hooks JSON を読み取り、cwd や caller が自動設定されます。

```json
{
  "hooks": {
    "Stop": [{
      "matcher": "",
      "hooks": [{
        "type": "command",
        "command": "pyokotify ~/.claude/hooks/character.png --hooks -t '[$dir:$branch] Done!' -d 5"
      }]
    }]
  }
}
```

## テンプレート変数

`-t` オプションで使用可能:

| 変数      | 説明                       |
| --------- | -------------------------- |
| `$dir`    | ディレクトリ名             |
| `$branch` | Git ブランチ名             |
| `$cwd`    | フルパス                   |
| `$event`  | イベント名                 |
| `$tool`   | ツール名                   |
