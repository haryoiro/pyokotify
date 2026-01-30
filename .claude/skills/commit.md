# Commit Skill

コミットメッセージは以下の規約に従って作成する。

## フォーマット

```
<type>: <subject>

<body>
```

## タイプ (type)

| タイプ | 説明 |
|--------|------|
| `feat` | 新機能の追加 |
| `fix` | バグ修正 |
| `docs` | ドキュメントのみの変更 |
| `style` | コードの意味に影響しない変更（空白、フォーマット等） |
| `refactor` | バグ修正でも機能追加でもないコード変更 |
| `test` | テストの追加・修正 |
| `chore` | ビルド、ツール、依存関係等の変更 |
| `perf` | パフォーマンス改善 |
| `ci` | CI/CD の設定変更 |

## ルール

1. **言語**: 日本語で記述
2. **subject**: 50文字以内、体言止めまたは動詞終わり
3. **body**: 変更の理由・内容を簡潔に（箇条書き推奨）

## 例

### 機能追加
```
feat: ランダム方向モードの追加

- 下・左・右からランダムに出現
- --random-direction オプション追加
- 画像の自動回転対応
```

### バグ修正
```
fix: 吹き出しのしっぽが画像からずれる問題を修正

しっぽの根元を12px内側にオフセットして
吹き出し本体と重なるようにした
```

### リファクタリング
```
refactor: コードを意味単位でファイル分割

- Config: 設定・引数解析
- Direction: 出現方向・回転
- Geometry: 幾何計算
- Views: UI部品
- Controller: アプリロジック
```

### テスト
```
test: Geometry の単体テスト追加

- pointOnRectEdge のテスト
- calculateImageRect のテスト
- calculateTailPoints のテスト
```

### chore
```
chore: swift-format と mise の設定追加
```
