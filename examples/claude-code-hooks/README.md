# Claude Code Hooks Integration

Notify with pyokotify when Claude Code completes a task or needs input.

## Setup

1. Copy `notify.sh` to `~/.claude/hooks/`
2. Place your character image at `~/.claude/hooks/character.png`
3. Merge `settings.json` into `~/.claude/settings.json`

```console
$ cp notify.sh ~/.claude/hooks/
$ chmod +x ~/.claude/hooks/notify.sh
$ cp /path/to/character.png ~/.claude/hooks/
```

## Configuration

Edit `notify.sh` to customize:

- `PYOKOTIFY`: path to pyokotify binary
- `PYOKOTIFY_IMAGE`: path to character image
- `PYOKOTIFY_OPTS`: notification options (duration, peek height, etc.)
