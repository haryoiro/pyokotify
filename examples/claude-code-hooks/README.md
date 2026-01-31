# Claude Code Hooks Integration

Notify with pyokotify when Claude Code completes a task, needs input, or asks a question.

## Events

| Event | Trigger |
|-------|---------|
| `Stop` | Task completed |
| `Notification` | Permission required / Waiting for input |
| `PreToolUse` (AskUserQuestion) | Claude asks a question |

## Setup

1. Install pyokotify to `~/.local/bin/`
2. Copy files to `~/.claude/hooks/`
3. Merge hooks config into `~/.claude/settings.json`
4. Place your character image

```console
$ cp notify.sh ~/.claude/hooks/
$ chmod +x ~/.claude/hooks/notify.sh
$ cp /path/to/your/character.png ~/.claude/hooks/character.png
```

## Configuration

Edit `notify.sh` to customize:

| Variable | Description |
|----------|-------------|
| `PYOKOTIFY` | Path to pyokotify binary |
| `PYOKOTIFY_IMAGE` | Path to character image |
| `PYOKOTIFY_OPTS` | Options (duration, peek height, etc.) |

## Customization

Modify messages in `notify.sh`:

```bash
# Example: Japanese style
MESSAGE="$PROJECT_INFO 完了なのだ！"
MESSAGE="$PROJECT_INFO 質問があるのだ！"
MESSAGE="$PROJECT_INFO 許可が必要なのだ！"
```
