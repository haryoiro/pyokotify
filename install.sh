#!/bin/bash
set -euo pipefail

REPO="haryoiro/pyokotify"
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"

# 色付き出力
info() { printf "\033[34m[INFO]\033[0m %s\n" "$1"; }
success() { printf "\033[32m[OK]\033[0m %s\n" "$1"; }
error() { printf "\033[31m[ERROR]\033[0m %s\n" "$1" >&2; exit 1; }

# OS確認
[[ "$(uname -s)" == "Darwin" ]] || error "macOSのみ対応しています"

# 最新バージョンを取得
info "最新バージョンを確認中..."
VERSION=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
[[ -n "$VERSION" ]] || error "バージョン取得に失敗しました"
info "バージョン: $VERSION"

# ダウンロード
DOWNLOAD_URL="https://github.com/${REPO}/releases/download/${VERSION}/pyokotify-${VERSION}-macos.zip"
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

info "ダウンロード中..."
curl -fsSL "$DOWNLOAD_URL" -o "$TEMP_DIR/pyokotify.zip" || error "ダウンロードに失敗しました"

# 展開
info "展開中..."
unzip -q "$TEMP_DIR/pyokotify.zip" -d "$TEMP_DIR"

# インストール
info "$INSTALL_DIR にインストール中..."
if [[ ! -d "$INSTALL_DIR" ]]; then
    sudo mkdir -p "$INSTALL_DIR"
fi
if [[ -w "$INSTALL_DIR" ]]; then
    mv "$TEMP_DIR/pyokotify" "$INSTALL_DIR/"
else
    sudo mv "$TEMP_DIR/pyokotify" "$INSTALL_DIR/"
fi
chmod +x "$INSTALL_DIR/pyokotify"

success "pyokotify $VERSION をインストールしました"
echo ""
echo "使い方:"
echo "  pyokotify <画像パス>"
echo ""
echo "詳細: https://github.com/${REPO}"
