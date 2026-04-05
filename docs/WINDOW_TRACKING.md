# ウィンドウ追跡の仕様

pyokotifyは、通知クリック時に呼び出し元のウィンドウにフォーカスを戻す機能を持っています。
複数のウィンドウが開いている場合でも、正しいウィンドウを特定してフォーカスできます。

---

## アプリ検出の仕組み

### 汎用プロセスツリー検出

`ProcessDetector` はプロセスツリーを遡り、**最初に見つかったGUIアプリ（`NSRunningApplication`）** を呼び出し元として返します。
既知のアプリリストへの事前登録は不要で、任意のターミナルアプリが自動的に検出されます。

```
pyokotify → ... → claude → zsh → [最初のGUIアプリ = ターミナル]
```

- **既知アプリ** → TERM_PROGRAM名を返す（VSCode/IntelliJ等の特殊処理の判定に使用）
- **未知アプリ** → バンドルIDをそのまま返す（汎用フォーカス処理で使用）

### フォーカス復帰の優先順位（handleClick）

通知クリック時、以下の順序で処理されます:

1. **tmux** — `TMUX`環境変数で判定 → 実ターミナルにフォーカス＋ペイン復元
2. **VSCode** — プロセスツリー/環境変数で判定 → 専用ウィンドウ検出
3. **IntelliJ/JetBrains** — プロセスツリー/環境変数で判定 → 専用ウィンドウ検出
4. **汎用** — cwdベースのウィンドウタイトルマッチング → アプリ全体フォーカス

### 環境変数による補助判定

プロセスツリー検出が失敗した場合のフォールバック:

| 環境変数 | 用途 |
|---|---|
| `TERM_PROGRAM` | ターミナルアプリの識別（tmux/ghostty等） |
| `TMUX` | tmux環境の判定 |
| `CMUX_WORKSPACE_ID` | cmux（`TERM_PROGRAM=ghostty`だがGhosttyと区別） |
| `VSCODE_GIT_IPC_HANDLE` | VSCode環境の判定 |
| `__CFBundleIdentifier` | JetBrains IDE環境の判定 |
| `TERMINAL_EMULATOR` | JetBrains IDE環境の判定 |
| `__INTELLIJ_COMMAND_HISTFILE__` | JetBrains IDE環境の判定 |

---

## Space移動機能

### 概要

ターゲットウィンドウが別のSpace（仮想デスクトップ）にある場合、CGSプライベートAPIを使用してウィンドウを現在のSpaceに移動します。

### 技術詳細

```swift
// CGSプライベートAPI
CGSMoveWindowsToManagedSpace(connectionID, windowArray, currentSpaceID)
```

**処理フロー**:
1. `_AXUIElementGetWindow`でAXUIElementからCGWindowIDを取得
2. `CGSMainConnectionID`でCGS接続IDを取得
3. `CGSGetActiveSpace`で現在のSpace IDを取得
4. `CGSMoveWindowsToManagedSpace`でウィンドウを移動

### 注意事項

- CGSプライベートAPIはAppleの非公開APIのため、将来のmacOSで動作しなくなる可能性があります
- フルスクリーンSpaceの場合は`app.activate()`によるSpace移動にフォールバックします

---

## VSCode

### 検出方法の優先順位

以下の順序で検出を試み、最初に成功した方法でウィンドウをフォーカスします。

### 方法1: VSCODE_GIT_IPC_HANDLE からPlugin PWDを取得

VSCodeの統合ターミナルには`VSCODE_GIT_IPC_HANDLE`環境変数が設定されています。
この環境変数からVSCodeのPluginプロセスを特定し、そのプロセスの`PWD`環境変数を取得します。

**処理フロー**:
```
VSCODE_GIT_IPC_HANDLE (ソケットパス)
    ↓ lsof -U でソケットを持つプロセスを検索
Plugin PID (Code Helper Plugin)
    ↓ ps eww で環境変数を取得
Plugin PWD (/path/to/workspace)
    ↓ ディレクトリ名を抽出
プロジェクト名 → ウィンドウタイトルでマッチング
```

**利点**:
- ソケットはウィンドウごとにユニーク
- PluginのPWDはVSCodeが開いたワークスペースパス
- cwdがサブディレクトリでも正しいウィンドウを特定可能

**制限**:
- `VSCODE_GIT_IPC_HANDLE`が設定されていない環境では使用不可（Git拡張が無効など）

### 方法2: cwdからウィンドウをマッチング

hooks JSONで渡される`cwd`（作業ディレクトリ）を使用してウィンドウを探します。
マッチングは以下の優先順位で行われます:

#### 2a. フルパスマッチ（優先）

ウィンドウタイトルにcwdのフルパスが含まれるかをチェックします。
Ghostty等、タイトルにフルパスを表示するターミナルで有効です。

```
cwd: /Users/me/projects/myproject
ウィンドウタイトル: "zsh /Users/me/projects/myproject" → マッチ
```

#### 2b. フォルダ名マッチ（フォールバック）

フルパスマッチが失敗した場合、cwdのディレクトリ名でマッチングします。

```
cwd: /path/to/myproject → プロジェクト名: myproject
ウィンドウタイトル: "main.swift — myproject" → マッチ
```

**利点**: シンプルで高速、環境変数に依存しない
**制限**: ウィンドウタイトルにcwdまたはディレクトリ名が含まれていない場合は失敗

### 方法3: worktreeの親リポジトリ名でマッチング

cwdが`.worktrees`を含む場合、`/.worktrees/`より前のパスコンポーネントを親リポジトリ名として抽出し、マッチングします。

```
cwd: /path/to/myrepo/.worktrees/feature/branch → 親リポジトリ名: myrepo
ウィンドウタイトル: "main.swift — myrepo" → マッチ
```

**利点**: git worktree内で作業している場合でも、メインリポジトリのVSCodeウィンドウにフォーカスできる
**制限**: cwdが`.worktrees`パスを含む場合のみ有効

### 方法4: TTYからウィンドウタイトルを推測

現在のTTYデバイスからシェルプロセスを特定し、そのcwdからウィンドウタイトルを推測します。

### 方法5: フォールバック

上記の方法がすべて失敗した場合、VSCodeアプリをアクティブにします（特定のウィンドウは選択しない）。

## 技術詳細

### VSCODE_GIT_IPC_HANDLE

VSCodeのGit拡張が設定する環境変数で、各ウィンドウに固有のUnixソケットパスを含みます。

```
/var/folders/.../vscode-git-{socketId}.sock
```

このソケットは、VSCodeのCode Helper (Plugin)プロセスが保持しています。

### Pluginプロセスの特定

```bash
lsof -U | grep "vscode-git-{socketId}"
```

これにより、対象のソケットを開いているPluginプロセスのPIDを取得できます。

### Plugin PWDの取得

```bash
ps eww -o command= -p {pluginPid}
```

Pluginプロセスの環境変数から`PWD=...`を抽出します。
このPWDは、そのVSCodeウィンドウで開いているワークスペースのパスを示します。

### 対応IDE

- Visual Studio Code (`com.microsoft.VSCode`)
- VSCode Insiders (`com.microsoft.VSCodeInsiders`)
- VSCodium (`com.vscodium`)
- Cursor (`com.todesktop.230313mzl4w4u92`)

### 制限事項

- ウィンドウタイトルにプロジェクト名が含まれている必要がある
- VSCodeのGit拡張が有効である必要がある（デフォルトで有効）

---

## IntelliJ / JetBrains IDE

### 検出方法の優先順位

以下の順序で検出を試み、最初に成功した方法でウィンドウをフォーカスします。

### 方法1: cwdからウィンドウをマッチング

hooks JSONで渡される`cwd`（作業ディレクトリ）を使用してウィンドウを探します。
マッチングは以下の優先順位で行われます:

#### 1a. フルパスマッチ（優先）

ウィンドウタイトルにcwdのフルパスが含まれるかをチェックします。

```
cwd: /Users/me/projects/myproject
ウィンドウタイトル: "Terminal /Users/me/projects/myproject" → マッチ
```

#### 1b. フォルダ名マッチ（フォールバック）

フルパスマッチが失敗した場合、cwdのディレクトリ名でマッチングします。

```
cwd: /path/to/myproject → プロジェクト名: myproject
ウィンドウタイトル: "myproject – main.kt" → マッチ
```

**利点**: シンプルで高速
**制限**: ウィンドウタイトルにcwdまたはディレクトリ名が含まれていない場合は失敗

### 方法2: __CFBundleIdentifier + 親プロセスのcwd

JetBrains IDEのターミナルでは`__CFBundleIdentifier`環境変数が設定されています。
この環境変数でIDEを特定し、親プロセスのcwdからプロジェクト名を取得してマッチングします。

**処理フロー**:
```
__CFBundleIdentifier (例: com.jetbrains.intellij)
    ↓ 親プロセスのcwdを取得
親プロセス cwd (/path/to/project)
    ↓ ディレクトリ名を抽出
プロジェクト名 → ウィンドウタイトルでマッチング
```

**利点**: IDEが特定されているため、確実性が高い
**制限**: `__CFBundleIdentifier`が設定されていない環境では使用不可

### 方法3: 親プロセスのcwdから全IDE検索

親プロセスのcwdを取得し、全てのJetBrains IDEでウィンドウタイトルをマッチングします。

### 方法4: TTYからウィンドウタイトルを推測

現在のTTYデバイスからシェルプロセスを特定し、そのcwdからウィンドウタイトルを推測します。

### 方法5: フォールバック

上記の方法がすべて失敗した場合、JetBrains IDEアプリをアクティブにします（特定のウィンドウは選択しない）。

### 対応IDE

- IntelliJ IDEA (`com.jetbrains.intellij`, `com.jetbrains.intellij-EAP`, `com.jetbrains.intellij.ce`)
- WebStorm (`com.jetbrains.WebStorm`, `com.jetbrains.WebStorm-EAP`)
- PyCharm (`com.jetbrains.pycharm`, `com.jetbrains.pycharm-EAP`, `com.jetbrains.pycharm.ce`)
- GoLand (`com.jetbrains.goland`, `com.jetbrains.goland-EAP`)
- RubyMine (`com.jetbrains.rubymine`, `com.jetbrains.rubymine-EAP`)
- CLion (`com.jetbrains.CLion`, `com.jetbrains.CLion-EAP`)
- PhpStorm (`com.jetbrains.PhpStorm`, `com.jetbrains.PhpStorm-EAP`)
- Rider (`com.jetbrains.rider`, `com.jetbrains.rider-EAP`)
- AppCode (`com.jetbrains.AppCode`, `com.jetbrains.AppCode-EAP`)
- DataGrip (`com.jetbrains.datagrip`, `com.jetbrains.datagrip-EAP`)
- Fleet (`com.jetbrains.fleet`)

### 制限事項

- ウィンドウタイトルにプロジェクト名が含まれている必要がある

---

## tmux

### 概要

tmux内からpyokotifyが起動された場合、tmuxクライアントのプロセスツリーを辿って
実際のGUIターミナルアプリを特定し、通知クリック時にペインまで復元する。

### 検出フロー

```
TMUX環境変数 (/tmp/tmux-501/default,12345,0)
    ↓ ソケットパスを抽出
tmux list-clients -F '#{client_pid}'
    ↓ クライアントPIDを取得
クライアントPIDの親プロセスツリーを探索
    ↓ NSRunningApplication とバンドルIDをマッチング
実際のターミナルアプリ (iTerm2, Ghostty, Terminal.app 等)
```

### 環境判定

以下の条件で tmux 環境と判定:

- `TMUX` 環境変数が設定されている

tmux判定はVSCode/IntelliJ判定より**先に**行われる。
VSCodeのターミナル内でtmuxを使うケースは稀であり、tmux固有のペイン復元が優先されるため。

### ペイン復元

通知クリック時、以下のコマンドでペインを復元:

```bash
# TMUX_PANE からペインが所属するウィンドウを特定
tmux display-message -t $TMUX_PANE -p '#{session_name}:#{window_index}'

# ウィンドウ切替 + ペイン選択
tmux select-window -t <session>:<window>
tmux select-pane -t $TMUX_PANE
```

### 親ターミナル検出（ProcessDetector連携）

`ProcessDetector.detectTerminalApp()` で `TERM_PROGRAM=tmux` を検出した場合、
`TmuxWindowDetector.detectRealTerminalApp()` に委譲して実際のターミナルを特定する。
これにより `config.callerApp` には tmux ではなく実際のターミナル名が設定される。

### tmuxバイナリの検索

`PATH`環境変数を検索し、見つからない場合は以下のフォールバックパスを使用:

1. `PATH`環境変数内のディレクトリ（nix-darwin等の非標準パスに対応）
2. `/opt/homebrew/bin/tmux` (Apple Silicon Homebrew)
3. `/usr/local/bin/tmux` (Intel Homebrew)
4. `/usr/bin/tmux` (システム)

### 制限事項

- tmuxバイナリが上記パスにない場合、ペイン復元は動作しない
- デタッチ中のセッションでは元のペインに戻れない場合がある
- tmux内でさらにtmuxをネストしている場合は未対応

---

## cmux

### 概要

cmux（`com.cmuxterm.app`）はlibghosttyベースのターミナルアプリ。
`TERM_PROGRAM=ghostty` を設定するため、Ghosttyとの区別に固有の環境変数を使用する。

### 検出方法

1. **プロセスツリー検出（優先）**: バンドルID `com.cmuxterm.app` / `com.cmuxterm.app.nightly` で検出
2. **環境変数フォールバック**: `TERM_PROGRAM=ghostty` かつ `CMUX_WORKSPACE_ID` が設定されている場合にcmuxと判定

### 対応バンドルID

- `com.cmuxterm.app`（Production）
- `com.cmuxterm.app.nightly`（Nightly）

---

## 汎用ターミナル

### 概要

上記の特殊処理対象（tmux、VSCode、IntelliJ）以外のターミナルアプリは、
**汎用プロセスツリー検出 + cwdベースのウィンドウマッチング**で自動対応します。

BundleIDRegistryへの事前登録は不要です。

### 検出フロー

```
プロセスツリーを遡り、最初のNSRunningApplicationを検出
    ↓ バンドルIDを取得
バンドルIDが既知 → TERM_PROGRAM名で返す
バンドルIDが未知 → バンドルIDをそのまま返す
    ↓
getCallerBundleId()でバンドルIDを解決
    ↓
Accessibility APIでウィンドウタイトルマッチ → フォーカス復帰
```

### フォーカス復帰

1. cwdのフルパスでウィンドウタイトルをマッチ（Ghostty等）
2. cwdのフォルダ名でウィンドウタイトルをマッチ
3. フォールバック: アプリ全体にフォーカス

---

## 共通の制限事項

- macOS専用（Accessibility API、lsof、psコマンドに依存）
- ウィンドウタイトルにプロジェクト名が含まれている必要がある
- Space移動機能はCGSプライベートAPIを使用しており、将来のmacOSで動作しなくなる可能性がある

## デバッグ

ログはmacOSの統合ログシステムに出力されます。Console.app または以下のコマンドで確認できます。

```console
# ウィンドウ検出ログをリアルタイムで確認
log stream --predicate 'subsystem == "com.haryoiro.pyokotify" AND category == "focus"' --level debug

# 全カテゴリを確認
log stream --predicate 'subsystem == "com.haryoiro.pyokotify"' --level debug
```

カテゴリ一覧:

| カテゴリ | 内容 |
|---------|------|
| `app` | 起動・設定・画像読み込み |
| `focus` | ウィンドウフォーカス・AX API操作 |
| `hooks` | Claude Code / Copilot CLI JSON解析 |
| `sound` | サウンド再生 |
| `git` | gitコマンド実行 |
| `process` | プロセス検出・TTY操作 |
