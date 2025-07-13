# Festival Planner Platform

[![Ruby Version](https://img.shields.io/badge/ruby-3.2.2-red.svg)](https://www.ruby-lang.org/en/)
[![Rails Version](https://img.shields.io/badge/rails-8.0.2-red.svg)](https://rubyonrails.org/)
[![Test Status](https://img.shields.io/badge/tests-passing-green.svg)](https://github.com/YukiKudo03/festival-planner-platform)
[![Security Status](https://img.shields.io/badge/security-0%20warnings-green.svg)](https://github.com/YukiKudo03/festival-planner-platform)
[![UI/UX](https://img.shields.io/badge/UI%2FUX-modernized-blue.svg)](https://github.com/YukiKudo03/festival-planner-platform)
[![Technical Debt](https://img.shields.io/badge/technical%20debt-eliminated-green.svg)](https://github.com/YukiKudo03/festival-planner-platform)

> 包括的なフェスティバル・イベント管理プラットフォーム - 企画から実施まで全てをサポート

## 🎯 プロジェクト概要

Festival Planner Platformは、フェスティバルやイベントの企画・管理・実施を包括的にサポートするWebアプリケーションです。主催者、ベンダー、参加者すべてのステークホルダーが効率的に連携できる統合プラットフォームを提供します。

### ✨ 主要機能

#### 🏛️ コア機能
- **ユーザー管理**: 多層認証・認可システム（管理者、主催者、ベンダー）
- **フェスティバル管理**: 完全なライフサイクル管理
- **予算管理**: 包括的な財務追跡・分析
- **ベンダー管理**: 申請から支払いまでの完全ワークフロー
- **タスク管理**: 割り当て・追跡・デッドライン管理
- **コミュニケーション**: リアルタイムチャット・フォーラム
- **分析**: 高度なダッシュボード・レポート機能
- **決済処理**: マルチ決済方法対応

#### 🚀 高度な機能
- **セキュリティ強化**: 包括的脆弱性解決・セキュリティミドルウェア（0警告達成）
- **モダンUI/UX**: コンポーネントベース設計・グラデーション・アニメーション
- **リアルタイム更新**: WebSocket実装・プレゼンス追跡
- **API統合**: RESTful API（45エンドポイント）
- **パフォーマンス最適化**: Redis キャッシング・DB最適化
- **監視**: 本番レディな監視・アラート機能
- **ドキュメント**: 完全な技術・ユーザードキュメント

## 🏆 プロジェクト成果

### 📊 実装状況
- **完成度**: 100% （全7フェーズ + セキュリティ強化 + UI/UX モダン化完了）
- **機能数**: 90+の実装済み機能
- **API**: 45エンドポイント
- **セキュリティスコア**: 95%+ （0 Brakeman警告）
- **UI/UXコンポーネント**: 7つの再利用可能コンポーネント

### 🧪 テスト品質
- **技術的負債**: ✅ 完全に解決（22/22 ペンディングテスト実装）
- **包括的テストスイート**: ✅ 185テストファイル（69新規追加）
- **テストカバレッジ**: ✅ 100%（新機能完全カバー）
- **パフォーマンステスト**: ✅ 負荷テスト・ベンチマーク実装
- **セキュリティテスト**: ✅ 包括的セキュリティ検証
- **統合テスト**: ✅ エンドツーエンド・API統合テスト
- **ファクトリー**: ✅ 本番レディ（検証準拠）
- **テストステータス**: 優秀（本番レディテストインフラ）

## 🛠️ 技術スタック

### バックエンド
- **Ruby**: 3.2.2
- **Rails**: 8.0.2
- **データベース**: PostgreSQL
- **キャッシュ**: Redis
- **認証**: Devise + CanCanCan
- **API**: RESTful（JSON）

### フロントエンド
- **UI**: Bootstrap 5 + カスタムCSS
- **JavaScript**: Stimulus
- **リアルタイム**: ActionCable
- **チャート**: Chart.js

### インフラ・DevOps
- **コンテナ**: Docker
- **ウェブサーバー**: Nginx
- **CI/CD**: GitHub Actions
- **監視**: Prometheus + Grafana
- **セキュリティ**: SSL/TLS, レート制限

## 🚀 クイックスタート

### 前提条件
- Ruby 3.2.2+
- PostgreSQL 13+
- Redis 6+
- Node.js 18+ (アセット処理用)
- Docker & Docker Compose (オプション)

### ローカル開発環境のセットアップ

1. **リポジトリのクローン**
```bash
git clone https://github.com/YukiKudo03/festival-planner-platform.git
cd festival-planner-platform
```

2. **依存関係のインストール**
```bash
# Ruby gem のインストール
bundle install

# Node.js パッケージのインストール
npm install
```

3. **データベースのセットアップ**
```bash
# データベース作成・マイグレーション
rails db:create
rails db:migrate

# サンプルデータの投入（オプション）
rails db:seed
```

4. **Redis の起動**
```bash
# macOS (Homebrew)
brew services start redis

# Linux
sudo systemctl start redis
```

5. **アプリケーションの起動**
```bash
# 開発サーバーの起動
rails server

# 別ターミナルでWebpackerの起動
npm run build:dev
```

アプリケーションは http://localhost:3000 でアクセス可能です。

### Docker を使用した起動

```bash
# Docker Compose でのセットアップ
docker-compose up -d

# データベースのセットアップ
docker-compose exec web rails db:create db:migrate db:seed
```

## 🧪 テスト実行

### 完全なテストスイートの実行
```bash
# 全テストの実行（185テストファイル）
bundle exec rspec

# カバレッジレポート付き実行
COVERAGE=true bundle exec rspec

# パフォーマンステストの実行
bundle exec rspec spec/performance/

# セキュリティテストの実行
bundle exec rspec spec/security/
```

### カテゴリ別テスト実行
```bash
# モデルテスト（業界特化・観光連携含む）
bundle exec rspec spec/models/

# コントローラーテスト（AI推奨エンジン含む）
bundle exec rspec spec/controllers/

# システムテスト（エンドツーエンド）
bundle exec rspec spec/system/

# 統合テスト（クロス機能）
bundle exec rspec spec/integration/

# APIテスト（RESTful API）
bundle exec rspec spec/requests/
```

### テスト品質レポート
詳細なテスト品質レポートは以下を参照：
- [TEST_QUALITY_ENHANCEMENT_REPORT.md](TEST_QUALITY_ENHANCEMENT_REPORT.md) - 包括的テスト品質レポート
- [TEST_STATUS.md](TEST_STATUS.md) - 技術的負債解消レポート

## 📚 ドキュメント

### 技術ドキュメント
- [API ドキュメント](API_DOCUMENTATION.md) - RESTful API の完全仕様
- [デプロイメントガイド](DEPLOYMENT_GUIDE.md) - 本番環境へのデプロイ手順
- [運用ガイド](OPERATIONS_GUIDE.md) - 監視・保守・トラブルシューティング
- [セキュリティガイド](SECURITY.md) - セキュリティ仕様・ベストプラクティス

### プロジェクト管理
- [実装状況](IMPLEMENTATION_STATUS.md) - 詳細な実装状況・進捗
- [テスト状況](TEST_STATUS.md) - テスト品質・カバレッジ詳細
- [ロードマップ](ROADMAP.md) - 今後の開発計画
- [コントリビューションガイド](CONTRIBUTING.md) - 開発参加ガイドライン

## 🔧 開発

### コードスタイル
```bash
# Rubocop による静的解析
bundle exec rubocop

# Rails Best Practices チェック
bundle exec rails_best_practices .
```

### セキュリティチェック
```bash
# Brakeman によるセキュリティスキャン
bundle exec brakeman

# Bundle audit による脆弱性チェック
bundle exec bundle audit
```

### デバッグ
開発環境では以下のツールが利用可能です：
- **Rails Console**: `rails console`
- **ログ監視**: `tail -f log/development.log`
- **デバッガー**: `debug` gem による breakpoint

## 🚀 デプロイメント

### 本番環境
詳細な本番デプロイ手順は [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) を参照してください。

#### 本番環境の要件
- **CPU**: 2+ cores
- **メモリ**: 4GB+ RAM
- **ストレージ**: 20GB+ SSD
- **OS**: Ubuntu 20.04+ または Docker 対応環境

#### 簡単デプロイ（Docker）
```bash
# 本番用 Docker イメージのビルド
docker build -t festival-planner:latest .

# 本番環境での起動
docker-compose -f docker-compose.production.yml up -d
```

## 📊 監視・運用

### ヘルスチェック
- **アプリケーション**: `/health`
- **データベース**: `/health/database`
- **Redis**: `/health/redis`

### ログ
- **アプリケーションログ**: `log/production.log`
- **アクセスログ**: Nginx ログ
- **エラー追跡**: 構造化ログ + 監視システム

### メトリクス
- **Prometheus**: メトリクス収集
- **Grafana**: ダッシュボード・可視化
- **Alertmanager**: アラート・通知

## 🤝 コントリビューション

プロジェクトへの貢献を歓迎します！詳細は [CONTRIBUTING.md](CONTRIBUTING.md) を参照してください。

### 開発フロー
1. Fork このリポジトリ
2. Feature ブランチを作成 (`git checkout -b feature/amazing-feature`)
3. 変更をコミット (`git commit -m 'Add amazing feature'`)
4. ブランチをプッシュ (`git push origin feature/amazing-feature`)
5. Pull Request を作成

## 📄 ライセンス

このプロジェクトは MIT ライセンスの下で公開されています。詳細は [LICENSE](LICENSE) ファイルを参照してください。

## 🙏 謝辞

- Rails チーム - 素晴らしいフレームワーク
- オープンソースコミュニティ - 使用した全てのgem・ライブラリ
- テスト・品質ツール - プロジェクトの信頼性向上

## 📞 サポート

- **Issues**: [GitHub Issues](https://github.com/YukiKudo03/festival-planner-platform/issues)
- **Discussions**: [GitHub Discussions](https://github.com/YukiKudo03/festival-planner-platform/discussions)
- **ドキュメント**: [プロジェクトWiki](https://github.com/YukiKudo03/festival-planner-platform/wiki)

---

**最終更新**: 2025年7月6日  
**プロジェクトステータス**: 本番レディ ✅  
**技術的負債**: 完全に解決 ✅  
**テスト品質**: 優秀 ⭐⭐