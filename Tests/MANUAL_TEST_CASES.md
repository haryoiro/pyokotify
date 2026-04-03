# 手動テストケース

## 実行方法

```bash
# リリースビルド
swift build -c release

# テストスクリプト（対話式）
bash tests/manual-test.sh

# デバッグログ付き直接実行
PYOKOTIFY_DEBUG=1 .build/release/pyokotify /tmp/pyokotify-test.png -d 10 -t "test" --cwd "$(pwd)"
```

---

## A. ターミナル検出（汎用）

### A-1: 既知ターミナルからの起動
| # | ターミナル | 期待するcallerApp | 確認ポイント |
|---|---|---|---|
| A-1a | Ghostty | `ghostty` | フォーカス復帰 |
| A-1b | iTerm2 | `iTerm.app` | フォーカス復帰 |
| A-1c | Terminal.app | `Apple_Terminal` | フォーカス復帰 |
| A-1d | Alacritty | `Alacritty` | フォーカス復帰 |
| A-1e | Kitty | `kitty` | フォーカス復帰 |
| A-1f | Warp | `WarpTerminal` | フォーカス復帰 |
| A-1g | cmux | `cmux` | Ghosttyと区別されているか |

### A-2: 未知ターミナルからの起動
**前提**: BundleIDRegistryに登録されていないターミナルアプリ
**期待**: バンドルID（例: `com.example.newterm`）がそのまま使われ、フォーカス復帰する

### A-3: 複数ターミナルが同時起動
**前提**: Ghostty と iTerm2 を両方開き、同じプロジェクトディレクトリで作業
**手順**:
1. Ghostty でpyokotifyを実行 → クリック → Ghosttyに戻るか
2. iTerm2 でpyokotifyを実行 → クリック → iTerm2に戻るか

**確認**: 別のターミナルにフォーカスが飛ばないこと

---

## B. tmux

### B-1: 基本動作
| # | 前提 | 手順 | 期待 |
|---|---|---|---|
| B-1a | tmux + Ghostty | tmux内でpyokotify実行→クリック | Ghosttyにフォーカス復帰 |
| B-1b | tmux + iTerm2 | 同上 | iTerm2にフォーカス復帰 |
| B-1c | tmux + Terminal.app | 同上 | Terminal.appにフォーカス復帰 |
| B-1d | tmux + cmux | 同上 | cmuxにフォーカス復帰 |

### B-2: ペイン復元
| # | 前提 | 手順 | 期待 |
|---|---|---|---|
| B-2a | 2分割ペイン | ペイン0で実行→ペイン1に移動→クリック | ペイン0が選択される |
| B-2b | 3分割ペイン | ペイン0で実行→ペイン2に移動→クリック | ペイン0が選択される |
| B-2c | 縦横混合分割 | 左ペインで実行→右下ペインに移動→クリック | 左ペインが選択される |

### B-3: ウィンドウ復元
| # | 前提 | 手順 | 期待 |
|---|---|---|---|
| B-3a | 2ウィンドウ | window 0で実行→window 1に移動→クリック | window 0に切り替わる |
| B-3b | 3ウィンドウ | window 0で実行→window 2に移動→クリック | window 0に切り替わる |

### B-4: セッション
| # | 前提 | 手順 | 期待 |
|---|---|---|---|
| B-4a | 2セッション、同一クライアント | session-aで実行→session-bに切替→クリック | session-aのペインが復元 |
| B-4b | 2セッション、別クライアント | session-aで実行→別ターミナルでsession-bにアタッチ→クリック | session-aのターミナルにフォーカス |

### B-5: エッジケース
| # | 前提 | 手順 | 期待 |
|---|---|---|---|
| B-5a | detach状態 | 実行→detach→通知表示中にクリック | クラッシュしない。可能ならアプリにフォーカス |
| B-5b | tmuxネスト | tmux内でさらにtmux | 外側のターミナルにフォーカスが戻る（ペイン復元は不定） |
| B-5c | カスタムソケット | `tmux -S /tmp/my.sock` | 検出・復元が動作する |
| B-5d | 複数クライアント同一セッション | 2つのターミナルから同じセッションにアタッチ | いずれかのターミナルにフォーカスが戻る |

---

## C. ウィンドウマッチング

### C-1: 同一ディレクトリ名
**前提**: ターミナルAで `/Users/me/work/myproject`、ターミナルBで `/Users/me/personal/myproject` を開く
**手順**: ターミナルAからpyokotify実行→クリック
**確認**:
- フルパスマッチが優先されるか（`/Users/me/work/myproject`）
- フルパスがタイトルに含まれないターミナルの場合、フォルダ名マッチになり曖昧になる可能性がある
**期待**: デバッグログでどのマッチ方法が使われたか確認

### C-2: ディレクトリ名が他のウィンドウタイトルの部分文字列
**前提**: ディレクトリ名が `api`、別ウィンドウのタイトルが `api-gateway — VSCode`
**手順**: `api` ディレクトリからpyokotify実行→クリック
**確認**: 間違ったウィンドウにフォーカスしないか（`contains`の曖昧マッチ問題）

### C-3: 非常に短いディレクトリ名
**前提**: ディレクトリ名が `a` や `x`
**手順**: 実行→クリック
**確認**: 無関係なウィンドウにマッチしないか

### C-4: 特殊文字を含むディレクトリ名
| # | ディレクトリ名 | 確認ポイント |
|---|---|---|
| C-4a | `my project` (スペース) | パスが正しく処理されるか |
| C-4b | `プロジェクト` (日本語) | Unicode対応 |
| C-4c | `my-project (1)` (括弧) | 特殊文字の処理 |
| C-4d | `project.name` (ドット) | バンドルIDと誤認しないか |

### C-5: worktree
| # | 前提 | 期待 |
|---|---|---|
| C-5a | `.worktrees/feature` 内で実行 | 親リポジトリ名でウィンドウマッチ（VSCode） |
| C-5b | worktree内、ターミナルのタイトルにworktreeパスが表示 | フルパスマッチが動作 |
| C-5c | worktreeのディレクトリ名がブランチ名と異なる | ディレクトリ名でマッチ（ブランチ名は使わない） |

### C-6: シンボリックリンク
**前提**: `/tmp/mylink -> /Users/me/work/myproject`
**手順**: `/tmp/mylink` から実行
**確認**: cwdがシンボリックリンクパスのままか、解決後のパスになるか。ウィンドウタイトルとのマッチに影響

---

## D. 同一/異なるブランチ × ターミナル

### D-1: 同じブランチ、違うターミナル
**前提**: Ghostty と iTerm2 で同じリポジトリ（同じブランチ）を開く
**手順**: 各ターミナルからpyokotify実行→クリック
**確認**: プロセスツリーで正しいターミナルが特定されるため、ディレクトリ名が同じでも問題なし

### D-2: 違うブランチ、同じターミナルアプリ
**前提**: Ghosttyで2つのウィンドウ。ウィンドウAは`main`、ウィンドウBは`feature`ブランチ
**手順**: ウィンドウAからpyokotify実行→ウィンドウBに切替→クリック
**確認**:
- ウィンドウタイトルにブランチ名が含まれる場合 → マッチ可能性あるが、cwdはディレクトリ名で照合
- 同じディレクトリなのでタイトルマッチが曖昧になる可能性（**既知の制限**）

### D-3: 違うブランチ、違うターミナルアプリ
**前提**: GhosttyでリポA/main、iTerm2でリポA/feature
**手順**: Ghosttyからpyokotify実行→iTerm2に切替→クリック
**確認**: Ghosttyにフォーカスが戻る（プロセスツリーで特定）

### D-4: worktree + 別ターミナル
**前提**: Ghosttyでメインリポ、iTerm2でworktree
**手順**: iTerm2（worktree）からpyokotify実行→クリック
**確認**: iTerm2にフォーカスが戻る

---

## E. macOS固有

### E-1: Space（仮想デスクトップ）
| # | 前提 | 期待 |
|---|---|---|
| E-1a | ターミナルが別Spaceにある | ウィンドウが現在のSpaceに移動される |
| E-1b | ターミナルがフルスクリーンSpace | フルスクリーンSpaceに切り替わる |

### E-2: ウィンドウ状態
| # | 前提 | 期待 |
|---|---|---|
| E-2a | ウィンドウが最小化されている | 復元されてフォーカスされる |
| E-2b | ウィンドウが別ウィンドウの後ろに隠れている | 前面に出る |

### E-3: アクセシビリティ権限
**前提**: アクセシビリティ権限が未付与
**確認**: ウィンドウタイトルマッチが失敗しフォールバック（アプリ全体にフォーカス）

---

## F. cmux固有

### F-1: cmux vs Ghostty の区別
**前提**: cmuxとGhosttyを同時起動
**手順**:
1. cmuxからpyokotify実行→クリック → cmuxに戻るか
2. Ghosttyからpyokotify実行→クリック → Ghosttyに戻るか

**確認**: `CMUX_WORKSPACE_ID` の有無で正しく判別されるか

### F-2: cmux nightly
**前提**: cmux nightly (`com.cmuxterm.app.nightly`) を使用
**確認**: バンドルIDで正しく検出されるか

---

## G. フォールバック

### G-1: プロセスツリー検出失敗
**前提**: SSH経由でログインし、ターミナルアプリがローカルにない
**確認**: TERM_PROGRAMフォールバックが動作

### G-2: TERM_PROGRAM未設定
**前提**: `unset TERM_PROGRAM` してから実行
**確認**: クラッシュしない。フォールバック（frontmostApplication）が使われる

### G-3: ウィンドウマッチ全失敗
**前提**: cwdが設定されていない、またはウィンドウタイトルにマッチしない
**確認**: アプリ全体にフォーカスされる

### G-4: callerAppもfallbackCallerAppもnil
**前提**: 検出が全て失敗
**確認**: クラッシュしない。通知は正常に消える

---

## 自動化に向けた分析

### 自動テスト可能な範囲（ロジックテスト）

現在テスト不可能だが、検出ロジックを純粋関数に抽出すれば自動化できるもの:

| 対象 | 現状 | 自動化の方法 |
|---|---|---|
| 環境判定（isVSCode / isIntelliJ / isTmux） | `ProcessInfo.processInfo.environment` 直参照 | 環境辞書を引数で受け取るように変更 |
| handleClickの分岐ロジック | private + GUI依存 | 「どのDetectorを使うか」の判定だけ抽出 |
| getCallerBundleId の解決 | 済 | ✅ 自動テスト済み |
| TMUXパース | 済 | ✅ 自動テスト済み |

### 自動テスト困難な範囲（GUI依存）

| 対象 | 理由 |
|---|---|
| 実際のフォーカス復帰 | NSRunningApplication / Accessibility API |
| Space移動 | CGSプライベートAPI |
| ウィンドウタイトルマッチ | AXUIElement |
| tmux select-pane | tmux実プロセスが必要 |
| プロセスツリー探索 | 実プロセス階層が必要 |

### 提案: 検出ロジックのテスタブル化

`handleClick` の「どの検出パスを取るか」を純粋関数として抽出する:

```swift
/// テスト可能な検出結果
enum FocusStrategy {
    case tmux(cwd: String?)
    case vscode(cwd: String?)
    case intellij(cwd: String?)
    case generic(bundleId: String?, cwd: String?)
    case fallback
}

/// 環境情報から検出戦略を決定（純粋関数、テスト可能）
static func determineFocusStrategy(
    callerApp: String?,
    cwd: String?,
    env: [String: String]
) -> FocusStrategy
```

これにより、環境変数の全組み合わせを自動テストでカバーできる。
GUI操作（実際のフォーカス）だけが手動テスト対象として残る。
