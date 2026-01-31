#!/bin/bash
# pyokotify notification script for Claude Code hooks

INPUT=$(cat)

# Configuration
PYOKOTIFY="$HOME/.local/bin/pyokotify"
PYOKOTIFY_IMAGE="$HOME/.claude/hooks/character.png"

# Parse input
EVENT_NAME=$(echo "$INPUT" | jq -r '.hook_event_name // "Unknown"')
CWD=$(echo "$INPUT" | jq -r '.cwd // ""')
PROJECT_NAME=$(basename "$CWD")

# Git branch (if available)
GIT_BRANCH=$(timeout 1 git -C "$CWD" branch --show-current 2>/dev/null || echo "")

# Project info
if [ -n "$GIT_BRANCH" ]; then
    PROJECT_INFO="[$PROJECT_NAME:$GIT_BRANCH]"
else
    PROJECT_INFO="[$PROJECT_NAME]"
fi

# Message based on event
case "$EVENT_NAME" in
  "Notification")
    NOTIFICATION_TYPE=$(echo "$INPUT" | jq -r '.notification_type // "unknown"')
    case "$NOTIFICATION_TYPE" in
      "permission_prompt")
        MESSAGE="$PROJECT_INFO Permission required!"
        ;;
      *)
        MESSAGE="$PROJECT_INFO Waiting for input!"
        ;;
    esac
    ;;
  "Stop")
    MESSAGE="$PROJECT_INFO Done!"
    ;;
  *)
    MESSAGE="$PROJECT_INFO $EVENT_NAME"
    ;;
esac

# Run pyokotify
if [ -f "$PYOKOTIFY" ] && [ -f "$PYOKOTIFY_IMAGE" ]; then
    PYOKOTIFY_OPTS="-t \"$MESSAGE\" -d 8 -p 200"

    if [ -n "$TERM_PROGRAM" ]; then
        PYOKOTIFY_OPTS="$PYOKOTIFY_OPTS --caller $TERM_PROGRAM"
    fi

    if [ -n "$CWD" ]; then
        PYOKOTIFY_OPTS="$PYOKOTIFY_OPTS --cwd $CWD"
    fi

    eval "\"$PYOKOTIFY\" \"$PYOKOTIFY_IMAGE\" $PYOKOTIFY_OPTS" &
fi

exit 0
