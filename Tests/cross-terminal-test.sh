#!/bin/bash
# =============================================================================
# クロスターミナル フォーカス復帰テスト
#
# 複数ターミナル × マルチプレクサ(tmux/zellij) × VSCode の組み合わせで
# pyokotifyが正しい起動元にフォーカスを戻すか検証する。
#
# 使い方:
#   swift build -c release
#   bash tests/cross-terminal-test.sh
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PYOKOTIFY="$PROJECT_DIR/.build/release/pyokotify"
IMG="/tmp/pyokotify-test.png"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

pass() { echo -e "  ${GREEN}PASS${NC} $1"; PASS_COUNT=$((PASS_COUNT + 1)); }
fail() { echo -e "  ${RED}FAIL${NC} $1 — $2"; FAIL_COUNT=$((FAIL_COUNT + 1)); }
skip() { echo -e "  ${YELLOW}SKIP${NC} $1 — $2"; SKIP_COUNT=$((SKIP_COUNT + 1)); }
info() { echo -e "  ${CYAN}INFO${NC} $1"; }
section() { echo ""; echo -e "${BOLD}=== $1 ===${NC}"; echo ""; }
test_header() { echo -e "  ${BOLD}--- $1 ---${NC}"; }

# =============================================================================
# ユーティリティ
# =============================================================================

get_frontmost_app() {
    osascript -e 'tell application "System Events" to get name of first process whose frontmost is true' 2>/dev/null
}

switch_to_finder() {
    osascript -e 'tell application "Finder" to activate' 2>/dev/null
    sleep 2
    osascript -e 'tell application "Finder" to activate' 2>/dev/null
    sleep 1
}

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

check_app_exists() { [ -d "/Applications/$1.app" ]; }

find_command() {
    local cmd="$1"
    command -v "$cmd" 2>/dev/null && return
    for p in /opt/homebrew/bin /usr/local/bin /usr/bin /run/current-system/sw/bin; do
        [ -x "$p/$cmd" ] && echo "$p/$cmd" && return
    done
    return 1
}

matches_app() {
    [ "$(echo "$1" | tr '[:upper:]' '[:lower:]')" = "$(echo "$2" | tr '[:upper:]' '[:lower:]')" ]
}

wait_for_result() {
    local result_file="$1" timeout="${2:-50}"
    local i=0
    while [ ! -f "$result_file" ] && [ $i -lt "$timeout" ]; do
        sleep 1
        i=$((i + 1))
    done
}

check_result() {
    local test_name="$1" expected_app="$2" result_file="$3"
    if [ ! -f "$result_file" ]; then
        fail "$test_name" "タイムアウト"
        return
    fi
    local result
    result=$(cat "$result_file")
    rm -f "$result_file"
    if echo "$result" | /usr/bin/grep -q "^SKIP:"; then
        skip "$test_name" "${result#SKIP:}"
    elif matches_app "$result" "$expected_app"; then
        pass "$test_name (→ $result)"
    else
        fail "$test_name" "期待: $expected_app, 実際: $result"
    fi
}

# =============================================================================
# テスト用スクリプト生成
# =============================================================================

# pyokotify実行 → フォーカス確認 の共通スクリプトを生成
# $1: 結果ファイルパス  $2: pyokotify追加引数
make_inner_script() {
    local result_file="$1"
    local pyoko_args="$2"
    local script="/tmp/pyoko-inner-$(date +%s)-$RANDOM.sh"
    cat > "$script" << INNER_EOF
#!/bin/bash
cd "$PROJECT_DIR"
sleep 1

osascript -e 'tell application "Finder" to activate' 2>/dev/null
sleep 2
osascript -e 'tell application "Finder" to activate' 2>/dev/null
sleep 1

BEFORE=\$(osascript -e 'tell application "System Events" to get name of first process whose frontmost is true' 2>/dev/null)
if [ "\$BEFORE" != "Finder" ]; then
    echo "SKIP:Finder切替失敗(\$BEFORE)" > "$result_file"
    exit 0
fi

"$PYOKOTIFY" "$IMG" -d 10 --auto-click $pyoko_args &
PID=\$!
sleep 5

AFTER=\$(osascript -e 'tell application "System Events" to get name of first process whose frontmost is true' 2>/dev/null)
echo "\$AFTER" > "$result_file"
wait \$PID 2>/dev/null || true
INNER_EOF
    chmod +x "$script"
    echo "$script"
}

# tmux attached で inner script を実行するラッパー
# tmuxがattachモードで起動するので、クライアントPIDがターミナルの子になる
# $1: inner script  $2: tmux binary
make_tmux_wrapper() {
    local inner="$1" tmux_bin="$2"
    local wrapper="/tmp/pyoko-tmux-wrap-$(date +%s)-$RANDOM.sh"
    cat > "$wrapper" << WRAPPER_EOF
#!/bin/bash
SESSION="pyoko-test-\$\$"
# attached mode（-d なし）: tmuxクライアントがこのターミナルで動く
"$tmux_bin" new-session -s "\$SESSION" "bash $inner; exit"
WRAPPER_EOF
    chmod +x "$wrapper"
    echo "$wrapper"
}

# zellij で inner script を実行するラッパー
# KDLレイアウトファイルを使い、inner scriptを実行するペインを起動
# スクリプト終了時にzellijも終了する
# $1: inner script  $2: zellij binary
make_zellij_wrapper() {
    local inner="$1" zellij_bin="$2"
    local layout="/tmp/pyoko-zellij-layout-$(date +%s)-$RANDOM.kdl"
    cat > "$layout" << LAYOUT_EOF
layout {
    pane command="bash" {
        args "$inner"
        close_on_exit true
    }
}
LAYOUT_EOF

    local wrapper="/tmp/pyoko-zellij-wrap-$(date +%s)-$RANDOM.sh"
    cat > "$wrapper" << WRAPPER_EOF
#!/bin/bash
SESSION="pyoko-test-\$\$"
"$zellij_bin" --session "\$SESSION" --layout "$layout" 2>/dev/null
# クリーンアップ
"$zellij_bin" delete-session "\$SESSION" --force 2>/dev/null || true
rm -f "$layout"
WRAPPER_EOF
    chmod +x "$wrapper"
    echo "$wrapper"
}

# =============================================================================
# テスト実行
# =============================================================================

# 現在のターミナルで直接テスト
run_local_test() {
    local test_name="$1" expected_app="$2"
    shift 2
    local extra_args=("$@")

    switch_to_finder
    if [ "$(get_frontmost_app)" != "Finder" ]; then
        skip "$test_name" "Finderに切替失敗"
        return
    fi

    "$PYOKOTIFY" "$IMG" -d 10 --auto-click "${extra_args[@]}" &
    local pid=$!
    sleep 5
    local after_app
    after_app=$(get_frontmost_app)
    wait "$pid" 2>/dev/null || true

    if matches_app "$after_app" "$expected_app"; then
        pass "$test_name (→ $after_app)"
    else
        fail "$test_name" "期待: $expected_app, 実際: $after_app"
    fi
}

# Ghosttyでスクリプトを実行し結果を検証
run_ghostty_test() {
    local test_name="$1" expected_app="$2" script="$3" result_file="$4"
    /Applications/Ghostty.app/Contents/MacOS/ghostty -e "$script" &
    wait_for_result "$result_file" 60
    check_result "$test_name" "$expected_app" "$result_file"
}

# Terminal.appでスクリプトを実行し結果を検証
run_terminal_app_test() {
    local test_name="$1" expected_app="$2" script="$3" result_file="$4"
    open -a Terminal "$script"
    wait_for_result "$result_file" 60
    check_result "$test_name" "$expected_app" "$result_file"
}

# 一時ファイルクリーンアップ
cleanup_tmp() {
    rm -f /tmp/pyoko-inner-* /tmp/pyoko-tmux-* /tmp/pyoko-zellij-* 2>/dev/null || true
}
trap cleanup_tmp EXIT

# =============================================================================
# メイン
# =============================================================================

echo ""
echo -e "${BOLD}============================================================${NC}"
echo -e "${BOLD} pyokotify クロスターミナル フォーカス復帰テスト${NC}"
echo -e "${BOLD}============================================================${NC}"
echo ""

if [ ! -x "$PYOKOTIFY" ]; then
    echo "ERROR: swift build -c release を先に実行してください"; exit 1
fi
ensure_test_image

CURRENT_TERMINAL=$(get_frontmost_app)
HAS_GHOSTTY=false; check_app_exists "Ghostty" && HAS_GHOSTTY=true
HAS_VSCODE=false; check_app_exists "Visual Studio Code" && HAS_VSCODE=true
TMUX_BIN=""; TMUX_BIN=$(find_command tmux) || true
ZELLIJ_BIN=""; ZELLIJ_BIN=$(find_command zellij) || true

info "現在のターミナル: $CURRENT_TERMINAL"
info "TERM_PROGRAM: ${TERM_PROGRAM:-未設定}"
info "TMUX: ${TMUX:+設定済み}${TMUX:-未設定}"
info "ZELLIJ: ${ZELLIJ:+設定済み}${ZELLIJ:-未設定}"
info "Ghostty: $($HAS_GHOSTTY && echo '✓' || echo '✗')"
info "VSCode: $($HAS_VSCODE && echo '✓' || echo '✗')"
info "tmux: ${TMUX_BIN:-✗}"
info "zellij: ${ZELLIJ_BIN:-✗}"
info "プロジェクト: $PROJECT_DIR"

# =============================================
section "A. 直接起動（ターミナル単体）"

test_header "A-1: $CURRENT_TERMINAL → $CURRENT_TERMINAL"
run_local_test "A-1: ${CURRENT_TERMINAL}→${CURRENT_TERMINAL}" "$CURRENT_TERMINAL" \
    -t "A-1" --cwd "$PROJECT_DIR"

if $HAS_GHOSTTY && ! matches_app "$CURRENT_TERMINAL" "ghostty"; then
    test_header "A-2: Ghostty → Ghostty"
    R="/tmp/pyoko-A2-$$"; rm -f "$R"
    S=$(make_inner_script "$R" "-t A-2 --cwd $PROJECT_DIR")
    run_ghostty_test "A-2: Ghostty→Ghostty" "Ghostty" "$S" "$R"
fi

# =============================================
if [ -n "$TMUX_BIN" ]; then
    section "B. tmux経由"

    if $HAS_GHOSTTY; then
        test_header "B-1: Ghostty + tmux → Ghostty"
        R="/tmp/pyoko-B1-$$"; rm -f "$R"
        INNER=$(make_inner_script "$R" "-t B-1 --cwd $PROJECT_DIR")
        WRAPPER=$(make_tmux_wrapper "$INNER" "$TMUX_BIN")
        run_ghostty_test "B-1: Ghostty+tmux→Ghostty" "Ghostty" "$WRAPPER" "$R"
    fi

    test_header "B-2: Terminal.app + tmux → Terminal"
    R="/tmp/pyoko-B2-$$"; rm -f "$R"
    INNER=$(make_inner_script "$R" "-t B-2 --cwd $PROJECT_DIR")
    WRAPPER=$(make_tmux_wrapper "$INNER" "$TMUX_BIN")
    run_terminal_app_test "B-2: Terminal.app+tmux→Terminal" "Terminal" "$WRAPPER" "$R"

    if $HAS_VSCODE; then
        test_header "B-3: VSCode + tmux（手動）"
        info "VSCode統合ターミナルでtmuxを起動し、その中で:"
        info "  $PYOKOTIFY $IMG -d 10 --auto-click -t B-3 --cwd $PROJECT_DIR"
        skip "B-3: VSCode+tmux" "手動実行が必要"
    fi
else
    section "B. tmux経由"
    skip "B: tmux全体" "tmux未インストール"
fi

# =============================================
if [ -n "$ZELLIJ_BIN" ]; then
    section "C. zellij経由"

    if $HAS_GHOSTTY; then
        test_header "C-1: Ghostty + zellij → Ghostty"
        R="/tmp/pyoko-C1-$$"; rm -f "$R"
        INNER=$(make_inner_script "$R" "-t C-1 --cwd $PROJECT_DIR")
        WRAPPER=$(make_zellij_wrapper "$INNER" "$ZELLIJ_BIN")
        run_ghostty_test "C-1: Ghostty+zellij→Ghostty" "Ghostty" "$WRAPPER" "$R"
    fi

    test_header "C-2: Terminal.app + zellij → Terminal"
    R="/tmp/pyoko-C2-$$"; rm -f "$R"
    INNER=$(make_inner_script "$R" "-t C-2 --cwd $PROJECT_DIR")
    WRAPPER=$(make_zellij_wrapper "$INNER" "$ZELLIJ_BIN")
    run_terminal_app_test "C-2: Terminal.app+zellij→Terminal" "Terminal" "$WRAPPER" "$R"
else
    section "C. zellij経由"
    skip "C: zellij全体" "zellij未インストール"
fi

# =============================================
section "D. クロスターミナル（同一cwd）"

if $HAS_GHOSTTY && ! matches_app "$CURRENT_TERMINAL" "ghostty"; then
    test_header "D-1: $CURRENT_TERMINAL から起動（Ghosttyも同じプロジェクト）"
    run_local_test "D-1: ${CURRENT_TERMINAL}→${CURRENT_TERMINAL}（Ghosttyではなく）" \
        "$CURRENT_TERMINAL" -t "D-1" --cwd "$PROJECT_DIR"

    test_header "D-2: Ghostty から起動（${CURRENT_TERMINAL}も同じプロジェクト）"
    R="/tmp/pyoko-D2-$$"; rm -f "$R"
    S=$(make_inner_script "$R" "-t D-2 --cwd $PROJECT_DIR")
    run_ghostty_test "D-2: Ghostty→Ghostty（${CURRENT_TERMINAL}ではなく）" "Ghostty" "$S" "$R"

    if [ -n "$TMUX_BIN" ]; then
        test_header "D-3: Ghostty(tmux) から起動（${CURRENT_TERMINAL}も同プロジェクト）"
        R="/tmp/pyoko-D3-$$"; rm -f "$R"
        INNER=$(make_inner_script "$R" "-t D-3 --cwd $PROJECT_DIR")
        WRAPPER=$(make_tmux_wrapper "$INNER" "$TMUX_BIN")
        run_ghostty_test "D-3: Ghostty(tmux)→Ghostty（${CURRENT_TERMINAL}ではなく）" \
            "Ghostty" "$WRAPPER" "$R"
    fi
fi

# =============================================
if $HAS_VSCODE; then
    section "E. VSCode固有（手動）"
    info "以下をVSCode統合ターミナルで手動実行:"
    echo ""
    info "E-1: VSCode 2ウィンドウ — 片方から起動→正しいウィンドウに戻るか"
    info "E-2: worktree内から起動 → 親リポジトリウィンドウに戻るか"
    info "E-3: VSCode内tmux → VSCodeに戻るか"
    info ""
    info "コマンド:"
    info "  $PYOKOTIFY $IMG -d 10 --auto-click -t 'E-test' --cwd \$PWD"
    skip "E: VSCode固有テスト" "手動実行が必要"
fi

# =============================================
echo ""
echo -e "${BOLD}============================================================${NC}"
echo -e " 結果: ${GREEN}PASS=$PASS_COUNT${NC}  ${RED}FAIL=$FAIL_COUNT${NC}  ${YELLOW}SKIP=$SKIP_COUNT${NC}"
echo -e "${BOLD}============================================================${NC}"
echo ""

[ "$FAIL_COUNT" -eq 0 ] && exit 0 || exit 1
