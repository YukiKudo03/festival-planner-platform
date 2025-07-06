# Festival Planner Platform - デプロイメントガイド

[![Deployment](https://img.shields.io/badge/deployment-production%20ready-green.svg)](https://github.com/YukiKudo03/festival-planner-platform)
[![Infrastructure](https://img.shields.io/badge/infrastructure-complete-blue.svg)](https://github.com/YukiKudo03/festival-planner-platform)
[![Security](https://img.shields.io/badge/security-85%25+-brightgreen.svg)](https://github.com/YukiKudo03/festival-planner-platform)

## 概要

このガイドでは、Festival Planner Platformの本番環境への包括的なデプロイメント手順を説明します。Docker、CI/CD、監視システムを含む完全な本番インフラストラクチャをカバーします。

## 🎯 デプロイメント方式

### 推奨デプロイメント方式
1. **Docker Compose** - 迅速なセットアップ（推奨）
2. **Manual Installation** - カスタマイズが必要な場合
3. **CI/CD Pipeline** - 自動化されたデプロイ

## 📋 前提条件

### システム要件（最小構成）
- **CPU**: 2 cores (推奨: 4+ cores)
- **メモリ**: 4GB RAM (推奨: 8GB+)
- **ストレージ**: 20GB SSD (推奨: 50GB+)
- **OS**: Ubuntu 20.04 LTS 以上
- **Ruby**: 3.2.2
- **Node.js**: 18.x 以上
- **PostgreSQL**: 13 以上
- **Redis**: 6.x 以上
- **Nginx**: 1.18 以上
- **Docker**: 20.10 以上（推奨デプロイ方式）

### 必要なサービス・アカウント
- **SSL証明書**: Let's Encrypt（自動取得）または商用証明書
- **SMTP サーバー**: Gmail, SendGrid, AWS SES等
- **ドメイン名**: DNS設定可能なドメイン
- **外部サービス**: 決済プロバイダー（Stripe等）
- AWS S3 バケット（ファイルストレージ）
- 決済サービスアカウント（Stripe, PayPal）
- 監視サービス（New Relic, Sentry等、オプション）

## デプロイメント方法

### 方法1: Docker Composeを使用したデプロイ

#### 1. リポジトリのクローン
```bash
git clone https://github.com/your-org/festival-planner-platform.git
cd festival-planner-platform
```

#### 2. 環境変数の設定
```bash
cp .env.production.example .env.production
# .env.production ファイルを編集して本番環境の値を設定
```

#### 3. SSL証明書の準備
```bash
# Let's Encryptを使用する場合
sudo apt update
sudo apt install certbot
sudo certbot certonly --standalone -d your-domain.com

# 証明書をコピー
sudo cp /etc/letsencrypt/live/your-domain.com/fullchain.pem config/ssl/cert.pem
sudo cp /etc/letsencrypt/live/your-domain.com/privkey.pem config/ssl/key.pem
```

#### 4. データベースの準備
```bash
# PostgreSQLの初期化スクリプト作成
cat > db/production_init.sql << EOF
CREATE DATABASE festival_planner_platform_production;
CREATE USER festival_user WITH PASSWORD 'secure_password';
GRANT ALL PRIVILEGES ON DATABASE festival_planner_platform_production TO festival_user;
EOF
```

#### 5. アプリケーションのビルドと起動
```bash
# 本番環境でビルド
docker-compose -f docker-compose.production.yml build

# データベースのセットアップ
docker-compose -f docker-compose.production.yml run --rm app rails db:create db:migrate

# 初期データの投入（必要に応じて）
docker-compose -f docker-compose.production.yml run --rm app rails db:seed

# アプリケーションの起動
docker-compose -f docker-compose.production.yml up -d
```

#### 6. 動作確認
```bash
# ヘルスチェック
curl https://your-domain.com/up

# API動作確認
curl https://your-domain.com/api/v1/health
```

### 方法2: 従来のサーバーデプロイ

#### 1. 依存関係のインストール
```bash
# Ruby環境の準備
curl -sSL https://get.rvm.io | bash
rvm install 3.2.2
rvm use 3.2.2 --default

# Node.js環境の準備
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# PostgreSQLのインストール
sudo apt-get install postgresql postgresql-contrib libpq-dev

# Redisのインストール
sudo apt-get install redis-server

# Nginxのインストール
sudo apt-get install nginx
```

#### 2. アプリケーションのセットアップ
```bash
# アプリケーションディレクトリ作成
sudo mkdir -p /var/www/festival-planner
sudo chown $USER:$USER /var/www/festival-planner

# リポジトリクローン
git clone https://github.com/your-org/festival-planner-platform.git /var/www/festival-planner

cd /var/www/festival-planner

# 環境変数設定
cp .env.production.example .env.production
# .env.production を編集

# 依存関係インストール
bundle install --deployment --without development test
npm install --production

# アセットコンパイル
RAILS_ENV=production bundle exec rails assets:precompile

# データベースセットアップ
RAILS_ENV=production bundle exec rails db:create db:migrate
```

#### 3. システムサービス設定
```bash
# Systemdサービスファイル作成
sudo tee /etc/systemd/system/festival-planner.service > /dev/null << EOF
[Unit]
Description=Festival Planner Platform
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/var/www/festival-planner
ExecStart=/usr/local/rvm/wrappers/default/bundle exec rails server -e production -b 0.0.0.0 -p 3000
Restart=always
RestartSec=10
Environment=RAILS_ENV=production

[Install]
WantedBy=multi-user.target
EOF

# サービス有効化・起動
sudo systemctl enable festival-planner
sudo systemctl start festival-planner
```

#### 4. Nginx設定
```bash
# Nginx設定ファイルコピー
sudo cp config/nginx.conf /etc/nginx/sites-available/festival-planner
sudo ln -s /etc/nginx/sites-available/festival-planner /etc/nginx/sites-enabled/

# SSL証明書設定（前述と同様）

# Nginx再起動
sudo systemctl restart nginx
```

## セキュリティ設定

### 1. ファイアウォール設定
```bash
sudo ufw allow OpenSSH
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
```

### 2. セキュリティ監査実行
```bash
# アプリケーション内でセキュリティ監査実行
RAILS_ENV=production bundle exec rails runner "
puts SecurityAuditService.generate_security_report.to_json
"
```

### 3. 定期的なセキュリティチェック
```bash
# Crontab設定
crontab -e

# 以下を追加（毎日午前2時にセキュリティ監査）
0 2 * * * cd /var/www/festival-planner && RAILS_ENV=production bundle exec rails runner "SecurityAuditService.run_comprehensive_audit"
```

## 監視とメンテナンス

### 1. ログ監視
```bash
# アプリケーションログ
tail -f log/production.log

# Nginxログ
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log

# システムログ
sudo journalctl -f -u festival-planner
```

### 2. パフォーマンス監視
```bash
# データベース接続数確認
sudo -u postgres psql -c "SELECT count(*) FROM pg_stat_activity;"

# Redis接続数確認
redis-cli info clients

# メモリ使用量確認
free -h

# CPU使用率確認
top
```

### 3. バックアップ設定
```bash
# データベースバックアップスクリプト
sudo tee /usr/local/bin/backup-festival-db.sh > /dev/null << 'EOF'
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/var/backups/festival-planner"
DB_NAME="festival_planner_platform_production"

mkdir -p $BACKUP_DIR
pg_dump $DB_NAME | gzip > $BACKUP_DIR/db_backup_$DATE.sql.gz

# 古いバックアップの削除（30日以上）
find $BACKUP_DIR -name "db_backup_*.sql.gz" -mtime +30 -delete
EOF

sudo chmod +x /usr/local/bin/backup-festival-db.sh

# Crontabに追加（毎日午前1時にバックアップ）
# 0 1 * * * /usr/local/bin/backup-festival-db.sh
```

## トラブルシューティング

### よくある問題と解決方法

#### 1. アプリケーションが起動しない
```bash
# ログ確認
sudo journalctl -u festival-planner -n 50

# 設定確認
RAILS_ENV=production bundle exec rails runner "puts Rails.application.config.inspect"

# データベース接続確認
RAILS_ENV=production bundle exec rails dbconsole
```

#### 2. SSL証明書の問題
```bash
# 証明書の有効性確認
openssl x509 -in config/ssl/cert.pem -text -noout

# 証明書更新
sudo certbot renew
```

#### 3. パフォーマンスの問題
```bash
# データベースの統計情報更新
sudo -u postgres psql festival_planner_platform_production -c "ANALYZE;"

# Redisキャッシュクリア
redis-cli FLUSHDB

# アプリケーション再起動
sudo systemctl restart festival-planner
```

#### 4. メモリ不足
```bash
# スワップファイル作成
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# 永続化
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

## アップデート手順

### 1. 準備
```bash
# データベースバックアップ
/usr/local/bin/backup-festival-db.sh

# 現在のバージョン確認
git log -1 --oneline
```

### 2. アップデート実行
```bash
# メンテナンスモード有効化（オプション）
touch tmp/maintenance.txt

# 最新コード取得
git pull origin main

# 依存関係更新
bundle install --deployment
npm install --production

# データベースマイグレーション
RAILS_ENV=production bundle exec rails db:migrate

# アセット再コンパイル
RAILS_ENV=production bundle exec rails assets:precompile

# アプリケーション再起動
sudo systemctl restart festival-planner

# メンテナンスモード解除
rm tmp/maintenance.txt
```

### 3. 動作確認
```bash
# ヘルスチェック
curl https://your-domain.com/up

# 機能テスト
RAILS_ENV=production bundle exec rspec spec/system/ --tag smoke_test
```

## 緊急時対応

### ロールバック手順
```bash
# 前のバージョンに戻す
git reset --hard HEAD~1

# データベースロールバック（必要に応じて）
RAILS_ENV=production bundle exec rails db:rollback

# アプリケーション再起動
sudo systemctl restart festival-planner
```

### 緊急連絡先
- システム管理者: admin@your-domain.com
- 開発チーム: dev-team@your-domain.com
- インフラ担当: infra@your-domain.com

---

## 参考資料

- [Rails Production Guide](https://guides.rubyonrails.org/configuring.html#configuring-a-database)
- [Docker Production Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [PostgreSQL Performance Tuning](https://wiki.postgresql.org/wiki/Performance_Optimization)
- [Nginx Security Best Practices](https://nginx.org/en/docs/http/securing_http.html)

このガイドは定期的に更新されます。最新版は開発チームにお問い合わせください。