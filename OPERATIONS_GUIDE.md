# Festival Planner Platform - 運用ガイドライン

## 📋 運用概要

このガイドでは、Festival Planner Platformの日常運用、監視、メンテナンス、緊急時対応について詳細に説明します。

## 🔧 日常運用手順

### 毎日の運用チェック

#### 朝のシステムチェック (9:00 AM)
```bash
# システム稼働状況確認
curl -f https://your-domain.com/up
curl -f https://your-domain.com/api/v1/health

# データベース接続確認
RAILS_ENV=production bundle exec rails runner "puts ActiveRecord::Base.connection.active?"

# Redis接続確認
redis-cli ping

# ディスク容量確認
df -h

# メモリ使用量確認
free -h
```

#### システムメトリクス確認
1. **Grafanaダッシュボード確認** (`https://your-domain.com:3001`)
   - CPU使用率 < 70%
   - メモリ使用率 < 80%
   - ディスク使用率 < 80%
   - レスポンス時間 < 200ms

2. **エラーログ確認**
```bash
# アプリケーションエラー
tail -100 log/production.log | grep ERROR

# Nginx エラー
sudo tail -100 /var/log/nginx/error.log

# システムエラー
sudo journalctl -u festival-planner -n 100 --no-pager
```

3. **セキュリティ監査実行**
```bash
RAILS_ENV=production bundle exec rails runner "
report = SecurityAuditService.generate_security_report
puts 'Security Score: ' + report[:audit][:overall_score].to_s + '%'
puts 'Critical Issues: ' + report[:audit][:critical_issues].length.to_s
"
```

### 週次運用タスク

#### 月曜日: バックアップ確認
```bash
# データベースバックアップ確認
ls -la /var/backups/festival-planner/
pg_dump festival_planner_platform_production | gzip > backup_test_$(date +%Y%m%d).sql.gz

# ファイルバックアップ確認 (S3)
aws s3 ls s3://your-backup-bucket/festival-planner/

# バックアップリストア テスト (月1回)
# テスト環境での復元テスト実施
```

#### 水曜日: パフォーマンス分析
```bash
# データベース統計更新
sudo -u postgres psql festival_planner_platform_production -c "ANALYZE;"

# スロークエリ分析
sudo -u postgres psql festival_planner_platform_production -c "
SELECT query, mean_exec_time, calls 
FROM pg_stat_statements 
ORDER BY mean_exec_time DESC 
LIMIT 10;"

# Redis メモリ使用量確認
redis-cli info memory
```

#### 金曜日: セキュリティチェック
```bash
# 依存関係脆弱性チェック
bundle audit

# SSL証明書有効期限確認
openssl x509 -in config/ssl/cert.pem -noout -dates

# 不正アクセス検知
sudo grep "403\|404\|429" /var/log/nginx/access.log | tail -50
```

### 月次運用タスク

#### 第1営業日: システム更新
1. **セキュリティアップデート**
```bash
# システムパッケージ更新
sudo apt update && sudo apt upgrade -y

# Gem 依存関係更新
bundle update --conservative

# npm パッケージ更新
npm audit fix
```

2. **パフォーマンス最適化**
```bash
# データベース最適化
RAILS_ENV=production bundle exec rails runner "
PerformanceOptimizationService.optimize_database_queries
PerformanceOptimizationService.warm_cache
"
```

#### 第2営業日: 容量管理
```bash
# ログローテーション確認
sudo logrotate -d /etc/logrotate.conf

# 古いファイル削除
find log/ -name "*.log.*" -mtime +30 -delete
find tmp/ -name "*" -mtime +7 -delete

# データベース容量分析
sudo -u postgres psql festival_planner_platform_production -c "
SELECT schemaname,tablename,attname,n_distinct,correlation 
FROM pg_stats 
WHERE schemaname='public' 
ORDER BY n_distinct DESC;"
```

#### 第3営業日: 監視・アラート
1. **監視設定確認**
```bash
# Prometheus 設定確認
curl http://localhost:9090/api/v1/targets

# アラートルール確認
curl http://localhost:9090/api/v1/rules
```

2. **通知テスト**
```bash
# メール通知テスト
RAILS_ENV=production bundle exec rails runner "
SystemMailer.maintenance_notification('test@example.com', 'Test alert').deliver_now
"

# Slack通知テスト（設定している場合）
curl -X POST -H 'Content-type: application/json' \
--data '{"text":"System monitoring test"}' \
YOUR_SLACK_WEBHOOK_URL
```

#### 第4営業日: レポート作成
```bash
# 月次運用レポート生成
RAILS_ENV=production bundle exec rails runner "
puts '=== Monthly Operations Report ==='
puts 'Festivals created: ' + Festival.where('created_at > ?', 1.month.ago).count.to_s
puts 'Payments processed: ' + Payment.where('created_at > ?', 1.month.ago).count.to_s
puts 'Total revenue: ¥' + Payment.completed.where('created_at > ?', 1.month.ago).sum(:amount).to_s
puts 'Active users: ' + User.where('last_sign_in_at > ?', 1.month.ago).count.to_s
puts '=================================='
"
```

## 📊 監視・アラート設定

### 重要メトリクス

#### システムメトリクス
- **CPU使用率**: > 80% で警告、> 90% で緊急
- **メモリ使用率**: > 85% で警告、> 95% で緊急
- **ディスク使用率**: > 80% で警告、> 90% で緊急
- **レスポンス時間**: > 500ms で警告、> 1000ms で緊急

#### アプリケーションメトリクス
- **エラー率**: > 1% で警告、> 5% で緊急
- **API稼働率**: < 99.5% で警告、< 99% で緊急
- **データベース接続**: 接続失敗で即座に緊急
- **決済失敗率**: > 2% で警告、> 5% で緊急

#### セキュリティメトリクス
- **不正アクセス**: 1分間に10回以上で警告
- **ブルートフォース**: 同一IPから5分間に20回以上で自動ブロック
- **SSL証明書**: 30日前に警告、7日前に緊急

### アラート設定例

#### Prometheus アラートルール
```yaml
# config/prometheus/alerts.yml
groups:
  - name: festival_planner_alerts
    rules:
      - alert: HighCPUUsage
        expr: cpu_usage_percent > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage detected"
          description: "CPU usage is above 80% for more than 5 minutes"

      - alert: DatabaseDown
        expr: up{job="postgresql"} == 0
        for: 0m
        labels:
          severity: critical
        annotations:
          summary: "Database is down"
          description: "PostgreSQL database is not responding"

      - alert: HighErrorRate
        expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.01
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "High error rate detected"
          description: "Error rate is above 1% for more than 2 minutes"
```

### 通知設定
```bash
# Slack Webhook設定
export SLACK_WEBHOOK_URL="https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK"

# メール通知設定
export ALERT_EMAIL="admin@your-domain.com"
export SMTP_SERVER="smtp.gmail.com"
```

## 🔧 定期メンテナンス

### 毎週のメンテナンス (日曜日 2:00 AM)

#### データベースメンテナンス
```bash
#!/bin/bash
# db_maintenance.sh

echo "Starting database maintenance..."

# データベース統計更新
sudo -u postgres psql festival_planner_platform_production -c "ANALYZE;"

# インデックス再構築 (必要に応じて)
sudo -u postgres psql festival_planner_platform_production -c "REINDEX DATABASE festival_planner_platform_production;"

# 不要データ削除
RAILS_ENV=production bundle exec rails runner "
# 古い通知の削除 (90日以上)
Notification.where('created_at < ?', 90.days.ago).delete_all

# 古いセッションの削除
ActiveRecord::SessionStore::Session.where('updated_at < ?', 30.days.ago).delete_all

# 一時ファイルの削除
Dir.glob('tmp/*').each { |f| File.delete(f) if File.mtime(f) < 7.days.ago }
"

echo "Database maintenance completed."
```

### 毎月のメンテナンス (第1日曜日 1:00 AM)

#### システム最適化
```bash
#!/bin/bash
# system_optimization.sh

echo "Starting system optimization..."

# パフォーマンス最適化サービス実行
RAILS_ENV=production bundle exec rails runner "
PerformanceOptimizationService.optimize_database_queries
PerformanceOptimizationService.setup_caching_strategies
PerformanceOptimizationService.warm_cache
"

# Nginx ログローテーション
sudo logrotate -f /etc/logrotate.d/nginx

# Redis メモリ最適化
redis-cli MEMORY PURGE

# システムキャッシュクリア
sudo sync && sudo sysctl vm.drop_caches=3

echo "System optimization completed."
```

### 四半期メンテナンス

#### セキュリティ監査
```bash
#!/bin/bash
# quarterly_security_audit.sh

echo "Starting quarterly security audit..."

# 包括的セキュリティ監査実行
RAILS_ENV=production bundle exec rails runner "
report = SecurityAuditService.generate_security_report
File.write('security_audit_' + Date.current.to_s + '.json', report.to_json)
puts 'Security audit completed. Score: ' + report[:audit][:overall_score].to_s + '%'
"

# 依存関係脆弱性チェック
bundle audit --update

# SSL設定チェック
openssl s_client -connect your-domain.com:443 -servername your-domain.com < /dev/null | openssl x509 -noout -dates

# ファイアウォール設定確認
sudo ufw status verbose

echo "Security audit completed."
```

## 🚨 緊急時対応手順

### 障害レベル定義

#### レベル1: 軽微 (警告)
- **影響**: 一部機能の性能低下
- **対応時間**: 営業時間内
- **対応者**: 運用担当者

#### レベル2: 中程度 (注意)
- **影響**: 重要機能の一部停止
- **対応時間**: 2時間以内
- **対応者**: 技術リード + 運用担当者

#### レベル3: 重大 (緊急)
- **影響**: システム全体またはセキュリティに関わる問題
- **対応時間**: 30分以内
- **対応者**: 全技術チーム + 経営陣

### 緊急時対応フロー

#### 1. 初期対応 (5分以内)
```bash
# システム状況確認
curl -f https://your-domain.com/up
curl -f https://your-domain.com/api/v1/health

# 直近のエラーログ確認
tail -50 log/production.log

# システムリソース確認
top
df -h
free -h
```

#### 2. 影響範囲特定 (10分以内)
```bash
# アクセス数確認
tail -100 /var/log/nginx/access.log | wc -l

# エラー率確認
tail -1000 /var/log/nginx/access.log | grep "5[0-9][0-9]" | wc -l

# データベース接続確認
sudo -u postgres psql festival_planner_platform_production -c "SELECT version();"
```

#### 3. 緊急対応実行
```bash
# サービス再起動
sudo systemctl restart festival-planner
sudo systemctl restart nginx

# データベース接続問題の場合
sudo systemctl restart postgresql

# Redis問題の場合
sudo systemctl restart redis

# 緊急メンテナンスページ表示
sudo cp /var/www/maintenance.html /var/www/html/index.html
```

### 災害復旧 (DR) 手順

#### データ復旧
```bash
# データベース復旧
sudo -u postgres psql -c "DROP DATABASE IF EXISTS festival_planner_platform_production;"
sudo -u postgres psql -c "CREATE DATABASE festival_planner_platform_production;"
gunzip -c /var/backups/festival-planner/latest_backup.sql.gz | sudo -u postgres psql festival_planner_platform_production

# ファイル復旧 (S3から)
aws s3 sync s3://your-backup-bucket/festival-planner/storage/ storage/

# 設定ファイル復旧
aws s3 sync s3://your-backup-bucket/festival-planner/config/ config/
```

#### システム再構築
```bash
# Docker環境での復旧
docker-compose -f docker-compose.production.yml down
docker-compose -f docker-compose.production.yml up -d

# データベースマイグレーション
docker-compose -f docker-compose.production.yml exec app rails db:migrate

# アセット再構築
docker-compose -f docker-compose.production.yml exec app rails assets:precompile
```

## 📈 パフォーマンス最適化

### 定期最適化タスク

#### データベース最適化 (週次)
```bash
# インデックス使用状況分析
sudo -u postgres psql festival_planner_platform_production -c "
SELECT schemaname, tablename, attname, n_distinct, correlation
FROM pg_stats 
WHERE schemaname = 'public' 
AND n_distinct > 100
ORDER BY n_distinct DESC;
"

# 未使用インデックス検出
sudo -u postgres psql festival_planner_platform_production -c "
SELECT indexrelname, relname, pg_size_pretty(pg_relation_size(indexrelname::regclass)) AS size
FROM pg_stat_user_indexes
WHERE idx_scan = 0
ORDER BY pg_relation_size(indexrelname::regclass) DESC;
"
```

#### キャッシュ最適化 (日次)
```bash
# Redis メモリ使用量分析
redis-cli --latency-history -i 1

# キャッシュヒット率確認
redis-cli info stats | grep keyspace

# キャッシュウォームアップ
RAILS_ENV=production bundle exec rails runner "
PerformanceOptimizationService.warm_cache
"
```

## 📊 レポート・分析

### 運用メトリクス収集

#### 日次レポート
```bash
#!/bin/bash
# daily_report.sh

DATE=$(date +%Y-%m-%d)
echo "=== Daily Operations Report - $DATE ===" > /var/log/festival-planner/daily_report_$DATE.txt

# システム稼働時間
uptime >> /var/log/festival-planner/daily_report_$DATE.txt

# ディスク使用量
df -h >> /var/log/festival-planner/daily_report_$DATE.txt

# アプリケーション統計
RAILS_ENV=production bundle exec rails runner "
puts 'Daily Active Users: ' + User.where('last_sign_in_at > ?', 1.day.ago).count.to_s
puts 'New Festivals: ' + Festival.where('created_at > ?', 1.day.ago).count.to_s  
puts 'Payments Today: ' + Payment.where('created_at > ?', 1.day.ago).count.to_s
puts 'Revenue Today: ¥' + Payment.completed.where('created_at > ?', 1.day.ago).sum(:amount).to_s
" >> /var/log/festival-planner/daily_report_$DATE.txt
```

#### 週次分析
```bash
# パフォーマンス分析
RAILS_ENV=production bundle exec rails runner "
puts '=== Weekly Performance Analysis ==='
puts 'Average Response Time: ' + (ActionController::Base.logger.info.scan(/Completed.*in (\d+)ms/).flatten.map(&:to_i).sum.to_f / 100).round(2).to_s + 'ms'
puts 'Error Rate: ' + (Rails.cache.read('error_count_week') || 0).to_s + '%'
puts 'Database Query Count: ' + ActiveRecord::Base.connection.query_cache.size.to_s
"
```

## 🔒 セキュリティ運用

### セキュリティチェックリスト

#### 日次セキュリティチェック
- [ ] SSL証明書有効性確認
- [ ] 不正アクセス試行ログ確認
- [ ] セキュリティ監査スコア確認 (> 80%)
- [ ] API使用量異常値チェック
- [ ] システム脆弱性アラート確認

#### 週次セキュリティチェック
- [ ] 依存関係脆弱性スキャン
- [ ] アクセスログ分析
- [ ] ユーザーアカウント棚卸し
- [ ] バックアップ暗号化確認
- [ ] セキュリティパッチ適用状況

#### 月次セキュリティチェック
- [ ] 包括的セキュリティ監査実行
- [ ] ペネトレーションテスト実施
- [ ] セキュリティポリシー見直し
- [ ] インシデント対応訓練
- [ ] セキュリティ教育実施

### インシデント対応

#### セキュリティインシデント検知
```bash
# 異常なアクセスパターン検知
sudo grep "$(date +%Y-%m-%d)" /var/log/nginx/access.log | \
awk '{print $1}' | sort | uniq -c | sort -nr | head -10

# ブルートフォース攻撃検知
sudo grep "failed.*password" /var/log/auth.log | \
awk '{print $(NF-3)}' | sort | uniq -c | sort -nr
```

#### 自動対応
```bash
# 不正IP自動ブロック
sudo iptables -A INPUT -s MALICIOUS_IP -j DROP

# 緊急アクセス制限
sudo ufw enable
sudo ufw default deny incoming
```

---

## 📞 連絡先・エスカレーション

### 緊急連絡先
- **システム管理者**: admin@your-domain.com / +81-90-XXXX-XXXX
- **技術リード**: tech-lead@your-domain.com / +81-90-XXXX-XXXX  
- **セキュリティ担当**: security@your-domain.com / +81-90-XXXX-XXXX
- **経営陣**: ceo@your-domain.com / +81-90-XXXX-XXXX

### エスカレーション基準
- **レベル1**: 運用担当者で対応
- **レベル2**: 技術リード + 運用担当者で対応
- **レベル3**: 全技術チーム + 経営陣で対応

### 外部サポート
- **クラウドプロバイダ**: AWS Support (Enterprise)
- **監視サービス**: New Relic / DataDog サポート
- **セキュリティ**: セキュリティ専門会社との契約

この運用ガイドラインに従って、Festival Planner Platformの安定した運用と継続的な改善を実現してください。