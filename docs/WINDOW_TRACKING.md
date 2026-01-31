# Pyokotify ウィンドウ追跡の仕組み

Pyokotifyは画面端からキャラクターを表示する通知アプリです。このドキュメントでは、アプリがウィンドウやフォーカスを追跡し、呼び出し元アプリケーションに戻る仕組みを解説します。

## 概要

Pyokotifyは継続的なウィンドウ監視は行わず、以下の限定的な追跡を実装しています：

1. **起動時のフロントアプリ記録** - `NSWorkspace.shared.frontmostApplication`
2. **クリック時のウィンドウ検索** - Accessibility API使用
3. **呼び出し元への復帰** - `NSRunningApplication.activate()`

---

## アーキテクチャ全体図

```mermaid
graph TB
    subgraph "macOS System"
        NSWorkspace["NSWorkspace<br/>(フロントアプリ取得)"]
        AccessibilityAPI["Accessibility API<br/>(ウィンドウ操作)"]
        NSScreen["NSScreen<br/>(画面情報)"]
    end

    subgraph "Pyokotify Application"
        Main["main.swift<br/>(エントリーポイント)"]
        AppDelegate["PyokotifyAppDelegate<br/>(アプリ初期化)"]
        Controller["PyokotifyController<br/>(メインロジック)"]
        Config["PyokotifyConfig<br/>(設定管理)"]
        Window["PyokotifyWindow<br/>(ウィンドウ)"]
        View["PyokotifyView<br/>(描画・イベント)"]
    end

    Main --> AppDelegate
    AppDelegate --> Controller
    Controller --> Config
    Controller --> Window
    Window --> View

    Controller -.->|起動時取得| NSWorkspace
    Controller -.->|クリック時検索| AccessibilityAPI
    Controller -.->|位置計算| NSScreen
    View -.->|クリックイベント| Controller
```

---

## クラス構成図

```mermaid
classDiagram
    class PyokotifyAppDelegate {
        -controller: PyokotifyController?
        +applicationDidFinishLaunching()
    }

    class PyokotifyController {
        -config: PyokotifyConfig
        -window: PyokotifyWindow?
        -callerApp: NSRunningApplication?
        -hideTimer: DispatchWorkItem?
        -currentDirection: PeekDirection
        +run()
        -animateIn()
        -animateOut()
        -handleClick()
        -focusWindowByCwd() Bool
        -getCallerApp() NSRunningApplication?
    }

    class PyokotifyConfig {
        +imagePath: String
        +displayDuration: Double
        +animationDuration: Double
        +callerApp: String?
        +cwd: String?
        +parse() PyokotifyConfig
        +getCallerBundleId() String?
    }

    class PyokotifyWindow {
        +init(frame, styleMask)
    }

    class PyokotifyView {
        -imageView: NSImageView
        -bubbleView: SpeechBubbleView?
        -onClick: (() -> Void)?
        +mouseDown(event)
        +mouseEntered(event)
        +mouseExited(event)
    }

    class PeekDirection {
        <<enumeration>>
        bottom
        left
        right
        +rotationDegrees: CGFloat
    }

    PyokotifyAppDelegate --> PyokotifyController
    PyokotifyController --> PyokotifyConfig
    PyokotifyController --> PyokotifyWindow
    PyokotifyController --> PeekDirection
    PyokotifyWindow --> PyokotifyView
```

---

## ウィンドウ追跡のフロー

### 1. 起動時のフロントアプリ記録

```mermaid
sequenceDiagram
    participant User as ユーザー
    participant Terminal as ターミナル/IDE
    participant Pyokotify as Pyokotify
    participant NSWorkspace as NSWorkspace

    User->>Terminal: コマンド実行<br/>pyokotify image.png
    Terminal->>Pyokotify: プロセス起動
    Pyokotify->>NSWorkspace: frontmostApplication取得
    NSWorkspace-->>Pyokotify: NSRunningApplication<br/>(Terminal/IDE)
    Pyokotify->>Pyokotify: callerAppとして保存
    Note over Pyokotify: この時点でフロントだった<br/>アプリを記録
```

### 2. クリック時のウィンドウ検索と復帰

```mermaid
sequenceDiagram
    participant User as ユーザー
    participant View as PyokotifyView
    participant Controller as PyokotifyController
    participant AX as Accessibility API
    participant App as 呼び出し元アプリ

    User->>View: マウスクリック
    View->>Controller: onClick()
    Controller->>Controller: focusWindowByCwd()

    alt CWDベースの検索が有効
        Controller->>AX: AXUIElementCreateApplication(pid)
        AX-->>Controller: AXUIElement
        Controller->>AX: AXUIElementCopyAttributeValue<br/>(kAXWindowsAttribute)
        AX-->>Controller: ウィンドウ一覧
        loop 各ウィンドウ
            Controller->>AX: AXUIElementCopyAttributeValue<br/>(kAXTitleAttribute)
            AX-->>Controller: ウィンドウタイトル
            Controller->>Controller: タイトルにフォルダ名が含まれるか確認
        end
        Controller->>AX: AXUIElementPerformAction<br/>(kAXRaiseAction)
        Controller->>App: activate()
    else フォールバック
        Controller->>App: activate()<br/>(記録済みcallerApp)
    end

    Controller->>Controller: animateOut()
    Controller->>Controller: NSApp.terminate()
```

---

## Accessibility API の使用詳細

```mermaid
flowchart TD
    subgraph "Accessibility API 呼び出し"
        A[focusWindowByCwd 開始] --> B{CWDとBundleID<br/>が存在?}
        B -->|No| Z[false を返す]
        B -->|Yes| C[AXUIElementCreateApplication<br/>pid からAXUIElement作成]
        C --> D[AXUIElementCopyAttributeValue<br/>kAXWindowsAttribute]
        D --> E{取得成功?}
        E -->|No| Z
        E -->|Yes| F[ウィンドウ配列をループ]
        F --> G[AXUIElementCopyAttributeValue<br/>kAXTitleAttribute]
        G --> H{タイトルに<br/>フォルダ名含む?}
        H -->|No| I{次のウィンドウ<br/>あり?}
        I -->|Yes| F
        I -->|No| Z
        H -->|Yes| J[AXUIElementPerformAction<br/>kAXRaiseAction]
        J --> K[app.activate]
        K --> Y[true を返す]
    end
```

---

## イベントフロー全体

```mermaid
stateDiagram-v2
    [*] --> 初期化: アプリ起動

    初期化 --> フロントアプリ記録: NSWorkspace.frontmostApplication
    フロントアプリ記録 --> 設定解析: コマンドライン引数
    設定解析 --> 画面情報取得: NSScreen.main
    画面情報取得 --> フレーム計算: direction に基づく
    フレーム計算 --> ウィンドウ作成: PyokotifyWindow
    ウィンドウ作成 --> アニメーションイン: animateIn()

    アニメーションイン --> 表示中: scheduleHide()

    表示中 --> アニメーションアウト: タイマー完了
    表示中 --> クリック処理: ユーザークリック

    クリック処理 --> ウィンドウ検索: focusWindowByCwd()
    ウィンドウ検索 --> アプリ復帰: activate()
    アプリ復帰 --> アニメーションアウト

    アニメーションアウト --> 終了: NSApp.terminate()
    終了 --> [*]

    note right of 表示中
        randomModeの場合は
        次のpyokoをスケジュール
    end note
```

---

## ターミナルプログラムのマッピング

呼び出し元アプリケーションを特定するために、環境変数 `TERM_PROGRAM` からBundleIDへのマッピングを使用します：

```mermaid
flowchart LR
    subgraph "環境変数"
        TERM[TERM_PROGRAM]
    end

    subgraph "マッピング"
        Map["termProgramToBundleId"]
    end

    subgraph "Bundle ID"
        VSCode["com.microsoft.VSCode"]
        iTerm["com.googlecode.iterm2"]
        Terminal["com.apple.Terminal"]
        Warp["dev.warp.Warp-Stable"]
        Ghostty["com.mitchellh.ghostty"]
        Alacritty["org.alacritty"]
        Kitty["net.kovidgoyal.kitty"]
    end

    TERM --> Map
    Map --> VSCode
    Map --> iTerm
    Map --> Terminal
    Map --> Warp
    Map --> Ghostty
    Map --> Alacritty
    Map --> Kitty
```

| TERM_PROGRAM | Bundle ID |
|--------------|-----------|
| vscode / VSCode | com.microsoft.VSCode |
| iTerm.app | com.googlecode.iterm2 |
| Apple_Terminal | com.apple.Terminal |
| WarpTerminal | dev.warp.Warp-Stable |
| ghostty / Ghostty | com.mitchellh.ghostty |
| Alacritty | org.alacritty |
| kitty | net.kovidgoyal.kitty |
| Hyper | co.zeit.hyper |
| Tabby | org.tabby |
| tmux | com.apple.Terminal |

---

## アニメーションシーケンス

```mermaid
sequenceDiagram
    participant C as Controller
    participant W as Window
    participant A as NSAnimationContext

    Note over C,A: animateIn() - 2フェーズ

    C->>A: beginGrouping()
    C->>A: duration = animationDuration * 0.6
    C->>A: timingFunction = easeOut
    C->>W: setFrame(overshootFrame)
    C->>A: endGrouping()

    Note over C,W: フェーズ1完了を待機

    C->>A: beginGrouping()
    C->>A: duration = animationDuration * 0.4
    C->>A: timingFunction = easeInEaseOut
    C->>W: setFrame(targetFrame)
    C->>A: endGrouping()

    Note over C,A: animateOut()

    C->>A: beginGrouping()
    C->>A: duration = animationDuration
    C->>A: timingFunction = easeIn
    C->>W: setFrame(exitFrame)
    C->>A: endGrouping()
```

---

## 技術的な制限事項

### 現在の実装の制限

1. **継続的な監視なし** - AXObserverを使用したリアルタイム監視は未実装
2. **メインスクリーンのみ** - `NSScreen.main` を固定で使用
3. **起動時スナップショット** - フロントアプリは起動時のみ記録

### 将来の拡張可能性

```mermaid
flowchart TD
    subgraph "現在の実装"
        A[起動時フロントアプリ記録]
        B[クリック時ウィンドウ検索]
    end

    subgraph "拡張可能性"
        C[AXObserver による<br/>リアルタイム監視]
        D[マルチスクリーン対応]
        E[ウィンドウ移動追従]
    end

    A -.-> C
    B -.-> E
```

---

## 関連ファイル

| ファイル | 役割 |
|---------|------|
| `Sources/pyokotify/main.swift` | エントリーポイント |
| `Sources/PyokotifyCore/Controller.swift` | メインロジック・ウィンドウ追跡 |
| `Sources/PyokotifyCore/Config.swift` | 設定管理・BundleIDマッピング |
| `Sources/PyokotifyCore/Views.swift` | UI・マウスイベント処理 |
| `Sources/PyokotifyCore/Direction.swift` | 表示方向管理 |
| `Sources/PyokotifyCore/Geometry.swift` | 座標計算 |
