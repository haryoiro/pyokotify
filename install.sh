#!/bin/bash
set -euo pipefail

REPO="haryoiro/pyokotify"
INSTALL_DIR="${HOME}/.local/bin"

# Logging functions
debug() {
  if [ "${PYOKOTIFY_DEBUG:-0}" = "1" ]; then
    echo "[DEBUG] $*" >&2
  fi
}

info() {
  if [ "${PYOKOTIFY_QUIET:-0}" != "1" ]; then
    printf "\033[34m[INFO]\033[0m %s\n" "$1" >&2
  fi
}

success() {
  if [ "${PYOKOTIFY_QUIET:-0}" != "1" ]; then
    printf "\033[32m[OK]\033[0m %s\n" "$1" >&2
  fi
}

warn() {
  printf "\033[33m[WARN]\033[0m %s\n" "$1" >&2
}

error() {
  printf "\033[31m[ERROR]\033[0m %s\n" "$1" >&2
  exit 1
}

# OS detection
get_os() {
  os="$(uname -s)"
  if [ "$os" = "Darwin" ]; then
    echo "macos"
  else
    error "Only macOS is supported (detected: $os)"
  fi
}

# Download function with curl/wget fallback
download() {
  url="$1"
  output="$2"
  debug "Downloading $url -> $output"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" -o "$output"
  elif command -v wget >/dev/null 2>&1; then
    wget -q "$url" -O "$output"
  else
    error "curl or wget is required"
  fi
}

# Checksum verification
verify_checksum() {
  file="$1"
  expected="$2"
  debug "Verifying checksum: $expected"
  if command -v shasum >/dev/null 2>&1; then
    actual=$(shasum -a 256 "$file" | cut -d ' ' -f 1)
  elif command -v sha256sum >/dev/null 2>&1; then
    actual=$(sha256sum "$file" | cut -d ' ' -f 1)
  else
    warn "shasum/sha256sum not found. Skipping checksum verification"
    return 0
  fi
  if [ "$actual" != "$expected" ]; then
    error "Checksum mismatch\n  Expected: $expected\n  Actual: $actual"
  fi
  debug "Checksum verified"
}

# Check if install dir is in PATH
check_path() {
  case ":$PATH:" in
    *":$INSTALL_DIR:"*)
      return 0
      ;;
  esac
  return 1
}

# Detect shell config file
get_shell_rc() {
  case "${SHELL:-}" in
    */zsh)
      echo "${ZDOTDIR:-$HOME}/.zshrc"
      ;;
    */bash)
      if [ -f "$HOME/.bash_profile" ]; then
        echo "$HOME/.bash_profile"
      else
        echo "$HOME/.bashrc"
      fi
      ;;
    */fish)
      echo "$HOME/.config/fish/config.fish"
      ;;
    *)
      echo "$HOME/.profile"
      ;;
  esac
}

# Main
main() {
  os=$(get_os)
  debug "OS: $os"

  # Get latest version
  info "Fetching latest version..."
  version=$(download "https://api.github.com/repos/${REPO}/releases/latest" - 2>/dev/null | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
  if [ -z "$version" ]; then
    error "Failed to fetch version"
  fi
  info "Version: $version"

  # Download URL
  archive_name="pyokotify-${version}-macos.zip"
  download_url="https://github.com/${REPO}/releases/download/${version}/${archive_name}"
  checksums_url="https://github.com/${REPO}/releases/download/${version}/checksums.txt"

  # Temp directory
  temp_dir=$(mktemp -d)
  trap 'rm -rf "$temp_dir"' EXIT
  debug "Temp dir: $temp_dir"

  # Download
  info "Downloading..."
  download "$download_url" "$temp_dir/$archive_name"

  # Checksum verification
  info "Verifying checksum..."
  if checksums=$(download "$checksums_url" - 2>/dev/null); then
    expected=$(echo "$checksums" | grep "$archive_name" | cut -d ' ' -f 1)
    if [ -n "$expected" ]; then
      verify_checksum "$temp_dir/$archive_name" "$expected"
    else
      warn "No matching entry in checksums file. Skipping verification"
    fi
  else
    warn "Checksums file not found. Skipping verification"
  fi

  # Extract
  info "Extracting..."
  unzip -q "$temp_dir/$archive_name" -d "$temp_dir"

  # Create install directory
  if [ ! -d "$INSTALL_DIR" ]; then
    debug "Creating $INSTALL_DIR"
    mkdir -p "$INSTALL_DIR"
  fi

  # Install
  info "Installing to $INSTALL_DIR..."
  mv "$temp_dir/pyokotify" "$INSTALL_DIR/"
  chmod +x "$INSTALL_DIR/pyokotify"

  # Create manifest.json
  MANIFEST_DIR="${HOME}/.local/share/pyokotify"
  mkdir -p "$MANIFEST_DIR"
  cat > "$MANIFEST_DIR/manifest.json" << EOF
{
  "version": "$version",
  "installed_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "files": [
    "$INSTALL_DIR/pyokotify"
  ]
}
EOF
  debug "Created manifest: $MANIFEST_DIR/manifest.json"

  success "Installed pyokotify $version"

  # PATH check and guidance
  if ! check_path; then
    echo ""
    warn "$INSTALL_DIR is not in your PATH"
    shell_rc=$(get_shell_rc)
    echo ""
    echo "Add the following to $shell_rc:"
    echo ""
    case "${SHELL:-}" in
      */fish)
        echo "  set -gx PATH \"$INSTALL_DIR\" \$PATH"
        ;;
      *)
        echo "  export PATH=\"$INSTALL_DIR:\$PATH\""
        ;;
    esac
    echo ""
    echo "Then restart your shell or run:"
    echo ""
    echo "  source $shell_rc"
    echo ""
  fi

  echo ""
  echo "Usage:"
  echo "  pyokotify <image-path>"
  echo ""
  echo "More info: https://github.com/${REPO}"
}

main "$@"
