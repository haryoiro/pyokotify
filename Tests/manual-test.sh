#!/bin/bash
# =============================================================================
# pyokotify 手動テストスクリプト
#
# 使い方:
#   1. このスクリプトを各テストシナリオのターミナルで実行
#   2. 通知が表示されたらクリック
#   3. フォーカスが正しいウィンドウに戻るか確認
#
# テスト用ビルド済みバイナリを使用（PYOKOTIFY_DEBUG=1 で詳細ログ出力）
# =============================================================================

set -euo pipefail

PYOKOTIFY="$(cd "$(dirname "$0")/.." && pwd)/.build/release/pyokotify"
IMG="/tmp/pyokotify-test.png"

# テスト用画像がなければ作成
if [ ! -f "$IMG" ]; then
    python3 -c "
import struct, zlib
def create_png(path, w=64, h=64):
    raw = b''
    for y in range(h):
        raw += b'\x00'
        for x in range(w):
            raw += struct.pack('BBBB', int(255*x/w), int(255*y/h), 200, 255)
    def chunk(ct, d):
        c = ct + d
        return struct.pack('>I', len(d)) + c + struct.pack('>I', zlib.crc32(c) & 0xffffffff)
    ihdr = struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0)
    with open(path, 'wb') as f:
        f.write(b'\x89PNG\r\n\x1a\n')
        f.write(chunk(b'IHDR', ihdr))
        f.write(chunk(b'IDAT', zlib.compress(raw)))
        f.write(chunk(b'IEND', b''))
create_png('$IMG')
"
fi

# ビルド確認
if [ ! -x "$PYOKOTIFY" ]; then
    echo "ERROR: ビルド済みバイナリが見つかりません。先に swift build -c release を実行してください"
    exit 1
fi

echo "============================================"
echo " pyokotify 手動テスト"
echo "============================================"
echo ""
echo "バイナリ: $PYOKOTIFY"
echo "ターミナル: ${TERM_PROGRAM:-unknown}"
echo "TMUX: ${TMUX:-なし}"
echo "TMUX_PANE: ${TMUX_PANE:-なし}"
echo "CMUX_WORKSPACE_ID: ${CMUX_WORKSPACE_ID:-なし}"
echo "CWD: $(pwd)"
echo "Git branch: $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'N/A')"
echo ""

# --- テスト選択 ---
echo "テストを選択してください:"
echo ""
echo "  1) 基本テスト — 通知表示 + クリックでフォーカス復帰"
echo "  2) cwd指定テスト — 特定ディレクトリのウィンドウにフォーカス"
echo "  3) デバッグテスト — 検出ログ付きで実行"
echo "  4) 全環境情報ダンプ（実行しない）"
echo ""
read -r -p "番号 [1]: " choice
choice="${choice:-1}"

case "$choice" in
    1)
        echo ""
        echo ">>> 通知を表示します。クリックしてフォーカスが戻るか確認してください"
        echo ""
        "$PYOKOTIFY" "$IMG" -d 10 -t "テスト: $(basename "$(pwd)") @ ${TERM_PROGRAM:-unknown}"
        ;;
    2)
        echo ""
        read -r -p "cwd パス [$(pwd)]: " cwd_path
        cwd_path="${cwd_path:-$(pwd)}"
        echo ""
        echo ">>> cwd=$cwd_path で通知を表示します"
        echo ""
        "$PYOKOTIFY" "$IMG" -d 10 -t "cwd: $(basename "$cwd_path")" --cwd "$cwd_path"
        ;;
    3)
        echo ""
        echo ">>> デバッグモードで通知を表示します（stderr にログ出力）"
        echo ""
        PYOKOTIFY_DEBUG=1 "$PYOKOTIFY" "$IMG" -d 10 -t "DEBUG: $(basename "$(pwd)")" --cwd "$(pwd)" 2>&1
        ;;
    4)
        echo ""
        echo "=== 環境情報 ==="
        echo "TERM_PROGRAM:     ${TERM_PROGRAM:-未設定}"
        echo "TERM:             ${TERM:-未設定}"
        echo "TMUX:             ${TMUX:-未設定}"
        echo "TMUX_PANE:        ${TMUX_PANE:-未設定}"
        echo "CMUX_WORKSPACE_ID: ${CMUX_WORKSPACE_ID:-未設定}"
        echo "CMUX_SURFACE_ID:  ${CMUX_SURFACE_ID:-未設定}"
        echo "VSCODE_GIT_IPC_HANDLE: ${VSCODE_GIT_IPC_HANDLE:-未設定}"
        echo "__CFBundleIdentifier:  ${__CFBundleIdentifier:-未設定}"
        echo "TERMINAL_EMULATOR:     ${TERMINAL_EMULATOR:-未設定}"
        echo ""
        echo "=== プロセスツリー ==="
        pid=$$
        for i in $(seq 1 10); do
            name=$(ps -p "$pid" -o comm= 2>/dev/null || echo "???")
            echo "  PID=$pid  $name"
            pid=$(ps -p "$pid" -o ppid= 2>/dev/null | tr -d ' ')
            [ -z "$pid" ] || [ "$pid" = "0" ] || [ "$pid" = "1" ] && break
        done
        echo ""
        echo "=== 実行中のターミナルアプリ ==="
        osascript -e '
            tell application "System Events"
                set appList to name of every process whose background only is false
            end tell
            return appList
        ' 2>/dev/null || echo "(取得失敗)"
        ;;
    *)
        echo "不正な選択です"
        exit 1
        ;;
esac
