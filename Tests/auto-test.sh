#!/bin/bash
# =============================================================================
# pyokotify 自動GUIテスト
#
# --auto-click を使い、各ターミナルエミュレータからの起動→フォーカス復帰を検証。
#
# 使い方:
#   swift build -c release
#   bash tests/auto-test.sh          # 現在のターミナルで基本テスト
#   bash tests/auto-test.sh --all    # エッジケース + 別ターミナルも
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PYOKOTIFY="$PROJECT_DIR/.build/release/pyokotify"
IMG="/tmp/pyokotify-test.png"

# --- 色付き出力 ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

pass() { echo -e "  ${GREEN}PASS${NC} $1"; PASS_COUNT=$((PASS_COUNT + 1)); }
fail() { echo -e "  ${RED}FAIL${NC} $1 — $2"; FAIL_COUNT=$((FAIL_COUNT + 1)); }
skip() { echo -e "  ${YELLOW}SKIP${NC} $1 — $2"; SKIP_COUNT=$((SKIP_COUNT + 1)); }
info() { echo -e "  ${CYAN}INFO${NC} $1"; }

# --- テスト用画像作成 ---
ensure_test_image() {
    [ -f "$IMG" ] && return
    python3 -c "
import struct, zlib
def f(p, w=64, h=64):
    r = b''
    for y in range(h):
        r += b'\x00'
        for x in range(w):
            r += struct.pack('BBBB', int(255*x/w), int(255*y/h), 200, 255)
    def c(t, d):
        v = t + d
        return struct.pack('>I', len(d)) + v + struct.pack('>I', zlib.crc32(v) & 0xffffffff)
    i = struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0)
    with open(p, 'wb') as f:
        f.write(b'\x89PNG\r\n\x1a\n')
        f.write(c(b'IHDR', i))
        f.write(c(b'IDAT', zlib.compress(r)))
        f.write(c(b'IEND', b''))
f('$IMG')
"
}

# --- ユーティリティ ---

get_frontmost_app() {
    osascript -e 'tell application "System Events" to get name of first process whose frontmost is true' 2>/dev/null
}

switch_to_finder() {
    osascript -e 'tell application "Finder" to activate' 2>/dev/null
    sleep 2
    osascript -e 'tell application "Finder" to activate' 2>/dev/null
    sleep 1
}

# --- 現在のターミナルでのテスト ---

run_focus_test() {
    local test_name="$1"
    local expected_app="$2"
    shift 2
    local extra_args=("$@")

    switch_to_finder
    local before_app
    before_app=$(get_frontmost_app)

    if [ "$before_app" != "Finder" ]; then
        skip "$test_name" "Finderにフォーカスを移せなかった (got: $before_app)"
        return
    fi

    "$PYOKOTIFY" "$IMG" -d 10 --auto-click "${extra_args[@]}" &
    local pyoko_pid=$!

    # アニメーション ~1s + auto-click delay 1s + フォーカス遷移
    sleep 4

    local after_app
    after_app=$(get_frontmost_app)
    wait "$pyoko_pid" 2>/dev/null || true

    if [ "$after_app" = "$expected_app" ]; then
        pass "$test_name (→ $after_app)"
    else
        fail "$test_name" "期待: $expected_app, 実際: $after_app"
    fi
}

# --- 別ターミナルでのテスト ---

# 別ターミナルでpyokotifyを起動し、フォーカスが戻るか検証
# $1: テスト名
# $2: ターミナルアプリのプロセス名（get_frontmost_appの返り値）
# $3: ターミナルで実行するコマンドを起動する方法
run_cross_terminal_test() {
    local test_name="$1"
    local expected_app="$2"
    local launch_method="$3"

    local RESULT_FILE="/tmp/pyokotify-cross-test-result-$$"
    rm -f "$RESULT_FILE"

    # 別ターミナル内で実行するスクリプトを生成
    local TEST_SCRIPT="/tmp/pyokotify-cross-test-$$.sh"
    cat > "$TEST_SCRIPT" << INNER_EOF
#!/bin/bash
# 少し待ってからFinderに切り替え
sleep 1
osascript -e 'tell application "Finder" to activate' 2>/dev/null
sleep 2
osascript -e 'tell application "Finder" to activate' 2>/dev/null
sleep 1

# Finderがフォアグラウンドか確認
BEFORE=\$(osascript -e 'tell application "System Events" to get name of first process whose frontmost is true' 2>/dev/null)
if [ "\$BEFORE" != "Finder" ]; then
    echo "SKIP:Finder切替失敗(\$BEFORE)" > "$RESULT_FILE"
    exit 0
fi

# pyokotify --auto-click
"$PYOKOTIFY" "$IMG" -d 10 --auto-click -t "$test_name" --cwd "$PROJECT_DIR" &
PID=\$!
sleep 5

AFTER=\$(osascript -e 'tell application "System Events" to get name of first process whose frontmost is true' 2>/dev/null)
wait \$PID 2>/dev/null || true

echo "\$AFTER" > "$RESULT_FILE"
INNER_EOF
    chmod +x "$TEST_SCRIPT"

    # ターミナルを起動してスクリプトを実行
    eval "$launch_method"

    # 結果を待つ（最大30秒）
    local i=0
    while [ ! -f "$RESULT_FILE" ] && [ $i -lt 30 ]; do
        sleep 1
        i=$((i + 1))
    done

    # 結果を確認
    if [ ! -f "$RESULT_FILE" ]; then
        fail "$test_name" "タイムアウト（結果ファイルが作成されなかった）"
    else
        local result
        result=$(cat "$RESULT_FILE")
        if echo "$result" | /usr/bin/grep -q "^SKIP:"; then
            skip "$test_name" "${result#SKIP:}"
        elif [ "$result" = "$expected_app" ]; then
            pass "$test_name (→ $result)"
        else
            fail "$test_name" "期待: $expected_app, 実際: $result"
        fi
    fi

    rm -f "$TEST_SCRIPT" "$RESULT_FILE"
}

# --- Ghosttyでテスト起動 ---
launch_in_ghostty() {
    local script="$TEST_SCRIPT"
    # Ghostty の --command オプションでスクリプトを実行
    if [ -x "/Applications/Ghostty.app/Contents/MacOS/ghostty" ]; then
        /Applications/Ghostty.app/Contents/MacOS/ghostty -e "$script" &
    else
        osascript -e "tell application \"Ghostty\" to activate" 2>/dev/null
        sleep 1
        # キーストロークでコマンドを送信（フォールバック）
        osascript -e "
            tell application \"System Events\"
                tell process \"Ghostty\"
                    keystroke \"bash $script\"
                    keystroke return
                end tell
            end tell
        " 2>/dev/null
    fi
}

# --- メイン ---

echo ""
echo "============================================"
echo " pyokotify 自動GUIテスト"
echo "============================================"
echo ""

if [ ! -x "$PYOKOTIFY" ]; then
    echo "ERROR: swift build -c release を先に実行してください"
    exit 1
fi

ensure_test_image

CURRENT_TERMINAL=$(get_frontmost_app)
info "ターミナル: $CURRENT_TERMINAL"
info "TERM_PROGRAM: ${TERM_PROGRAM:-未設定}"
info "TMUX: ${TMUX:+設定済み}${TMUX:-未設定}"
info "CWD: $(pwd)"
echo ""

# =============================================================
echo "=== A. 現在のターミナル ($CURRENT_TERMINAL) ==="
echo ""

echo "--- T1: 基本フォーカス復帰 ---"
run_focus_test \
    "T1: cwdあり → ターミナルに復帰" \
    "$CURRENT_TERMINAL" \
    -t "T1" --cwd "$(pwd)"
echo ""

echo "--- T2: プロジェクトdir指定 ---"
run_focus_test \
    "T2: --cwd でプロジェクトdir" \
    "$CURRENT_TERMINAL" \
    -t "T2" --cwd "$PROJECT_DIR"
echo ""

echo "--- T3: cwdなし ---"
run_focus_test \
    "T3: cwdなし → アプリ全体にフォーカス" \
    "$CURRENT_TERMINAL" \
    -t "T3"
echo ""

# =============================================================
if [ "${1:-}" = "--all" ]; then

    echo "=== B. エッジケース ==="
    echo ""

    echo "--- T4: 短いディレクトリ名 ---"
    SHORT_DIR="/tmp/a"
    mkdir -p "$SHORT_DIR"
    run_focus_test \
        "T4: dir名 'a'" \
        "$CURRENT_TERMINAL" \
        -t "T4" --cwd "$SHORT_DIR"
    echo ""

    echo "--- T5: 日本語ディレクトリ名 ---"
    JP_DIR="/tmp/プロジェクト"
    mkdir -p "$JP_DIR"
    run_focus_test \
        "T5: 日本語dir" \
        "$CURRENT_TERMINAL" \
        -t "T5" --cwd "$JP_DIR"
    echo ""

    echo "--- T6: スペース入りディレクトリ名 ---"
    SPACE_DIR="/tmp/my project"
    mkdir -p "$SPACE_DIR"
    run_focus_test \
        "T6: スペース入りdir" \
        "$CURRENT_TERMINAL" \
        -t "T6" --cwd "$SPACE_DIR"
    echo ""

    echo "--- T7: メッセージなし ---"
    run_focus_test \
        "T7: テキストなし（画像のみ）" \
        "$CURRENT_TERMINAL" \
        --cwd "$(pwd)"
    echo ""

    echo "--- T8: 存在しないcwd ---"
    run_focus_test \
        "T8: 存在しないcwd" \
        "$CURRENT_TERMINAL" \
        -t "T8" --cwd "/nonexistent/path/project"
    echo ""

    # =============================================================
    echo "=== C. 別ターミナルエミュレータ ==="
    echo ""

    # --- Ghostty ---
    if [ -d "/Applications/Ghostty.app" ]; then
        echo "--- T10: Ghostty → フォーカス復帰 ---"
        run_cross_terminal_test \
            "T10: Ghostty → フォーカス復帰" \
            "Ghostty" \
            "launch_in_ghostty"
        echo ""
    else
        skip "T10: Ghostty" "Ghostty.app が見つからない"
        echo ""
    fi

    # --- Terminal.app ---
    echo "--- T11: Terminal.app → フォーカス復帰 ---"
    run_cross_terminal_test \
        "T11: Terminal.app → フォーカス復帰" \
        "Terminal" \
        'open -a Terminal "$TEST_SCRIPT"'
    echo ""
fi

# =============================================================
echo "============================================"
echo -e " 結果: ${GREEN}PASS=$PASS_COUNT${NC}  ${RED}FAIL=$FAIL_COUNT${NC}  ${YELLOW}SKIP=$SKIP_COUNT${NC}"
echo "============================================"
echo ""

[ "$FAIL_COUNT" -eq 0 ] && exit 0 || exit 1
