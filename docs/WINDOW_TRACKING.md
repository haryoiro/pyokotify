# VSCode ウィンドウ追跡の仕様

pyokotifyは、通知クリック時に呼び出し元のVSCodeウィンドウにフォーカスを戻す機能を持っています。
複数のVSCodeウィンドウが開いている場合でも、正しいウィンドウを特定してフォーカスできます。

## 検出方法の優先順位

以下の順序で検出を試み、最初に成功した方法でウィンドウをフォーカスします。

### 方法1: cwdからプロジェクト名でマッチング

hooks JSONで渡される`cwd`（作業ディレクトリ）のディレクトリ名を取得し、
ウィンドウタイトルに含まれるウィンドウを探してフォーカスします。

```
cwd: /path/to/myproject → プロジェクト名: myproject
ウィンドウタイトル: "main.swift — myproject" → マッチ
```

**利点**: シンプルで高速
**制限**: ウィンドウタイトルにcwdのディレクトリ名が含まれていない場合は失敗

### 方法2: VSCODE_GIT_IPC_HANDLE からPlugin PWDを取得

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
- worktreeを使用している場合でも、正しいウィンドウを特定できる
- cwdとは異なるパスでウィンドウが開かれている場合に有効

**制限**:
- `lsof`と`ps`コマンドの実行が必要（若干のオーバーヘッド）
- `VSCODE_GIT_IPC_HANDLE`が設定されていない環境では使用不可

### 方法3: TTYからウィンドウタイトルを推測

現在のTTYデバイスからシェルプロセスを特定し、そのcwdからウィンドウタイトルを推測します。

### 方法4: フォールバック

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

## 対応IDE

- Visual Studio Code (`com.microsoft.VSCode`)
- VSCode Insiders (`com.microsoft.VSCodeInsiders`)
- VSCodium (`com.vscodium`)
- Cursor (`com.todesktop.230313mzl4w4u92`)

## 制限事項

- macOS専用（Accessibility API、lsof、psコマンドに依存）
- ウィンドウタイトルにプロジェクト名が含まれている必要がある
- VSCodeのGit拡張が有効である必要がある（`VSCODE_GIT_IPC_HANDLE`の設定に必要）
