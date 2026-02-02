#!/bin/bash
# pyokotify notification script for Claude Code hooks
#
# 新しい方法（推奨）:
#   pyokotify を直接 Claude Code hooks から呼び出す場合は、
#   このスクリプトは不要です。settings.json で直接指定できます:
#
#   {
#     "hooks": {
#       "Notification": [{
#         "command": "pyokotify ~/image.png --claude-hooks -d 8"
#       }]
#     }
#   }
#
# このスクリプトはカスタムメッセージやサウンドが必要な場合に使用します。

INPUT=$(cat)

# ===== 設定 =====
PYOKOTIFY="$HOME/.local/bin/pyokotify"
PYOKOTIFY_IMAGE="$HOME/.claude/hooks/character.png"
SOUNDS_DIR="$HOME/.claude/hooks/sounds"

# 基本情報
CWD=$(echo "$INPUT" | jq -r '.cwd // ""')
DIR_NAME=$(basename "$CWD")

# ===== メッセージと音声の定義 =====
# 配列: メッセージと対応する音声ファイルのペア
declare -a GOROKU_TEXT
declare -a GOROKU_SOUND

GOROKU_TEXT+=("Done!")
GOROKU_SOUND+=("done.mp3")

GOROKU_TEXT+=("Task completed!")
GOROKU_SOUND+=("complete.mp3")

GOROKU_TEXT+=("Finished!")
GOROKU_SOUND+=("finish.mp3")

# カスタムメッセージを追加する場合は以下のように:
# GOROKU_TEXT+=("カスタムメッセージ")
# GOROKU_SOUND+=("custom.mp3")

# ===== ランダム選択 =====
IDX=$((RANDOM % ${#GOROKU_TEXT[@]}))
RANDOM_GOROKU="${GOROKU_TEXT[$IDX]}"
RANDOM_SOUND="${SOUNDS_DIR}/${GOROKU_SOUND[$IDX]}"

# メッセージ: [ディレクトリ名] メッセージ
if [ -n "$DIR_NAME" ]; then
    MESSAGE="[$DIR_NAME] $RANDOM_GOROKU"
else
    MESSAGE="$RANDOM_GOROKU"
fi

# ===== pyokotify実行 =====
if [ -f "$PYOKOTIFY" ] && [ -f "$PYOKOTIFY_IMAGE" ]; then
    # 配列で引数を管理（evalを避けてインジェクション対策）
    PYOKOTIFY_ARGS=("-t" "$MESSAGE" "-d" "8" "-p" "200")

    # CWD で特定ウィンドウにフォーカス
    if [ -n "$CWD" ]; then
        PYOKOTIFY_ARGS+=("--cwd" "$CWD")
    fi

    # サウンド再生
    if [ -f "$RANDOM_SOUND" ]; then
        PYOKOTIFY_ARGS+=("--sound" "$RANDOM_SOUND")
    fi

    "$PYOKOTIFY" "$PYOKOTIFY_IMAGE" "${PYOKOTIFY_ARGS[@]}" &
fi

exit 0
