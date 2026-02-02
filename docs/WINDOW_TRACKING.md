# IDE ウィンドウ追跡の仕様

pyokotifyは、通知クリック時に呼び出し元のIDEウィンドウにフォーカスを戻す機能を持っています。
複数のウィンドウが開いている場合でも、正しいウィンドウを特定してフォーカスできます。

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

### 方法2: cwdからプロジェクト名でマッチング

hooks JSONで渡される`cwd`（作業ディレクトリ）のディレクトリ名を取得し、
ウィンドウタイトルに含まれるウィンドウを探してフォーカスします。

```
cwd: /path/to/myproject → プロジェクト名: myproject
ウィンドウタイトル: "main.swift — myproject" → マッチ
```

**利点**: シンプルで高速、環境変数に依存しない
**制限**: ウィンドウタイトルにcwdのディレクトリ名が含まれていない場合は失敗

### 方法3: worktreeの親リポジトリ名でマッチング

cwdが`.worktrees`を含む場合、親リポジトリ名を抽出してマッチングします。

```
cwd: /path/to/jigpo/.worktrees/feature/branch → 親リポジトリ名: jigpo
ウィンドウタイトル: "main.swift — jigpo" → マッチ
```

**利点**: worktree内で作業している場合でも親ウィンドウにフォーカスできる
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

### 方法1: cwdからプロジェクト名でマッチング

hooks JSONで渡される`cwd`（作業ディレクトリ）のディレクトリ名を取得し、
ウィンドウタイトルに含まれるウィンドウを探してフォーカスします。

```
cwd: /path/to/myproject → プロジェクト名: myproject
ウィンドウタイトル: "myproject – main.kt" → マッチ
```

**利点**: シンプルで高速
**制限**: ウィンドウタイトルにcwdのディレクトリ名が含まれていない場合は失敗

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

## 共通の制限事項

- macOS専用（Accessibility API、lsof、psコマンドに依存）
- ウィンドウタイトルにプロジェクト名が含まれている必要がある
