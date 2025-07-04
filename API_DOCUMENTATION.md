# Festival Planner Platform API Documentation

## 概要

Festival Planner Platform の RESTful API 仕様書です。本APIを使用して、祭りの管理、決済処理、分析データの取得などが可能です。

## 基本情報

- **Base URL**: `https://your-domain.com/api/v1`
- **認証方式**: Bearer Token
- **データ形式**: JSON
- **文字エンコーディング**: UTF-8

## 認証

すべてのAPIエンドポイントは認証が必要です。HTTPヘッダーに認証トークンを含めてください。

```http
Authorization: Bearer YOUR_API_TOKEN
Content-Type: application/json
```

### APIトークンの取得
APIトークンは管理画面でユーザーアカウントごとに生成できます。

## レート制限

APIには以下のレート制限が適用されます：

- **一般リクエスト**: 100リクエスト/分
- **APIトークン毎**: 100リクエスト/時間
- **決済API**: 10リクエスト/10分

制限に達した場合、HTTP 429ステータスコードが返されます。

## エラーレスポンス

```json
{
  "success": false,
  "error": "エラーコード",
  "message": "エラーメッセージ",
  "details": "詳細情報（オプション）"
}
```

### 主なエラーコード

- `400` - Bad Request: リクエストが不正
- `401` - Unauthorized: 認証が必要
- `403` - Forbidden: アクセス権限なし
- `404` - Not Found: リソースが見つからない
- `422` - Unprocessable Entity: バリデーションエラー
- `429` - Too Many Requests: レート制限超過
- `500` - Internal Server Error: サーバーエラー

## Festivals API

### 祭り一覧取得

```http
GET /api/v1/festivals
```

#### パラメータ

| パラメータ | 型 | 必須 | 説明 |
|---|---|---|---|
| page | integer | No | ページ番号（デフォルト: 1） |
| per_page | integer | No | 1ページあたりの件数（デフォルト: 25, 最大: 100） |
| filters | string | No | フィルター条件（JSON文字列） |
| sort | string | No | ソート条件 |

#### フィルター例

```json
{
  "status": "active",
  "start_date_from": "2024-01-01",
  "start_date_to": "2024-12-31",
  "public": true
}
```

#### レスポンス例

```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "name": "春祭り2024",
      "description": "地域の春を祝う祭り",
      "status": "active",
      "start_date": "2024-04-15",
      "end_date": "2024-04-17",
      "location": "中央公園",
      "budget": 500000,
      "capacity": 1000,
      "public": true,
      "vendor_count": 25,
      "completion_rate": 75.5,
      "total_revenue": 450000,
      "created_at": "2024-01-15T10:00:00Z",
      "updated_at": "2024-03-01T15:30:00Z"
    }
  ],
  "meta": {
    "current_page": 1,
    "total_pages": 5,
    "total_count": 123,
    "per_page": 25
  }
}
```

### 祭り詳細取得

```http
GET /api/v1/festivals/{id}
```

#### レスポンス例

```json
{
  "success": true,
  "data": {
    "id": 1,
    "name": "春祭り2024",
    "description": "地域の春を祝う祭り",
    "status": "active",
    "start_date": "2024-04-15",
    "end_date": "2024-04-17",
    "location": "中央公園",
    "budget": 500000,
    "capacity": 1000,
    "public": true,
    "venue": {
      "name": "中央公園メインステージ",
      "address": "東京都渋谷区1-1-1",
      "layout": "..."
    },
    "organizer": {
      "id": 10,
      "name": "田中太郎",
      "email": "tanaka@example.com"
    },
    "budget_categories": [
      {
        "id": 1,
        "name": "会場費",
        "budget_limit": 100000,
        "spent_amount": 80000
      }
    ],
    "statistics": {
      "vendor_count": 25,
      "task_completion_rate": 75.5,
      "total_revenue": 450000,
      "total_expenses": 320000
    }
  }
}
```

### 祭り作成

```http
POST /api/v1/festivals
```

#### リクエスト例

```json
{
  "festival": {
    "name": "夏祭り2024",
    "description": "地域の夏を楽しむ祭り",
    "start_date": "2024-07-15",
    "end_date": "2024-07-17",
    "location": "市民会館",
    "budget": 1000000,
    "capacity": 2000,
    "public": true
  }
}
```

#### レスポンス例

```json
{
  "success": true,
  "data": {
    "id": 2,
    "name": "夏祭り2024",
    "status": "planning",
    "created_at": "2024-03-15T10:00:00Z"
  },
  "message": "祭りを作成しました"
}
```

### 祭り更新

```http
PATCH /api/v1/festivals/{id}
```

### 祭り削除

```http
DELETE /api/v1/festivals/{id}
```

### 祭り分析データ取得

```http
GET /api/v1/festivals/{id}/analytics
```

#### パラメータ

| パラメータ | 型 | 必須 | 説明 |
|---|---|---|---|
| start_date | date | No | 分析期間開始日 |
| end_date | date | No | 分析期間終了日 |
| metrics | string | No | 取得するメトリクス（カンマ区切り） |

#### レスポンス例

```json
{
  "success": true,
  "data": {
    "overview": {
      "total_revenue": 450000,
      "total_expenses": 320000,
      "profit_margin": 28.9,
      "vendor_count": 25,
      "task_completion_rate": 75.5
    },
    "budget": {
      "total_budget": 500000,
      "spent_amount": 320000,
      "remaining_amount": 180000,
      "utilization_rate": 64.0,
      "categories": [
        {
          "name": "会場費",
          "budget": 100000,
          "spent": 80000,
          "percentage": 80.0
        }
      ]
    },
    "vendors": {
      "total_applications": 50,
      "approved_applications": 25,
      "approval_rate": 50.0,
      "revenue_by_category": {
        "食品": 200000,
        "物販": 150000,
        "ゲーム": 100000
      }
    },
    "tasks": {
      "total_tasks": 100,
      "completed_tasks": 75,
      "completion_rate": 75.0,
      "overdue_tasks": 5,
      "average_completion_days": 3.2
    },
    "trends": {
      "daily_revenue": [
        {"date": "2024-04-15", "amount": 150000},
        {"date": "2024-04-16", "amount": 180000},
        {"date": "2024-04-17", "amount": 120000}
      ]
    },
    "recommendations": [
      "予算の使用率が低いため、追加の宣伝活動を検討してください",
      "タスクの完了率が目標を下回っています。スケジュール調整が必要です"
    ]
  }
}
```

## Payments API

### 決済一覧取得

```http
GET /api/v1/festivals/{festival_id}/payments
```

#### パラメータ

| パラメータ | 型 | 必須 | 説明 |
|---|---|---|---|
| status | string | No | 決済ステータス |
| payment_method | string | No | 決済方法 |
| start_date | date | No | 期間開始日 |
| end_date | date | No | 期間終了日 |

#### レスポンス例

```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "amount": "5000.00",
      "currency": "JPY",
      "status": "completed",
      "payment_method": "stripe",
      "description": "出店料金",
      "customer_name": "山田花子",
      "customer_email": "yamada@example.com",
      "transaction_id": "txn_1234567890",
      "confirmation_code": "conf_123",
      "processing_fee": "150.00",
      "created_at": "2024-03-15T10:00:00Z",
      "confirmed_at": "2024-03-15T10:05:00Z"
    }
  ],
  "meta": {
    "current_page": 1,
    "total_pages": 3,
    "total_count": 67
  }
}
```

### 決済詳細取得

```http
GET /api/v1/festivals/{festival_id}/payments/{id}
```

### 決済作成

```http
POST /api/v1/festivals/{festival_id}/payments
```

#### リクエスト例

```json
{
  "payment": {
    "amount": 5000,
    "payment_method": "stripe",
    "description": "出店料金",
    "customer_email": "customer@example.com",
    "customer_name": "顧客名",
    "currency": "JPY"
  }
}
```

#### レスポンス例

```json
{
  "success": true,
  "data": {
    "id": 1,
    "amount": "5000.00",
    "status": "processing",
    "transaction_id": "txn_1234567890",
    "payment_instructions": {
      "type": "stripe",
      "client_secret": "pi_1234567890_secret_abcd",
      "publishable_key": "pk_live_abcd1234"
    }
  },
  "message": "決済処理を開始しました"
}
```

### 決済キャンセル

```http
DELETE /api/v1/festivals/{festival_id}/payments/{id}/cancel
```

#### リクエスト例

```json
{
  "reason": "顧客からのキャンセル要求"
}
```

### 決済確認（管理者のみ）

```http
POST /api/v1/payments/{id}/confirm
```

### 決済サマリー取得

```http
GET /api/v1/festivals/{festival_id}/payments/summary
```

#### パラメータ

| パラメータ | 型 | 必須 | 説明 |
|---|---|---|---|
| start_date | date | No | 集計期間開始日 |
| end_date | date | No | 集計期間終了日 |

#### レスポンス例

```json
{
  "success": true,
  "data": {
    "total_amount": 125000.00,
    "total_transactions": 25,
    "completed_transactions": 22,
    "pending_transactions": 2,
    "failed_transactions": 1,
    "average_transaction_amount": 5000.00,
    "total_fees": 3750.00,
    "net_amount": 121250.00,
    "by_payment_method": {
      "stripe": {
        "count": 20,
        "amount": 100000.00
      },
      "paypal": {
        "count": 3,
        "amount": 15000.00
      },
      "bank_transfer": {
        "count": 2,
        "amount": 10000.00
      }
    },
    "daily_summary": [
      {
        "date": "2024-03-15",
        "count": 5,
        "amount": 25000.00
      }
    ]
  }
}
```

## Vendor Applications API

### 出店申請一覧取得

```http
GET /api/v1/festivals/{festival_id}/vendor_applications
```

### 出店申請詳細取得

```http
GET /api/v1/festivals/{festival_id}/vendor_applications/{id}
```

### 出店申請作成

```http
POST /api/v1/festivals/{festival_id}/vendor_applications
```

### 出店申請承認/却下

```http
PATCH /api/v1/festivals/{festival_id}/vendor_applications/{id}/review
```

## Tasks API

### タスク一覧取得

```http
GET /api/v1/festivals/{festival_id}/tasks
```

### タスク作成

```http
POST /api/v1/festivals/{festival_id}/tasks
```

### タスク更新

```http
PATCH /api/v1/festivals/{festival_id}/tasks/{id}
```

## System API

### ヘルスチェック

```http
GET /api/v1/health
```

#### レスポンス例

```json
{
  "status": "healthy",
  "timestamp": "2024-03-15T10:00:00Z",
  "version": "1.0.0",
  "services": {
    "database": "healthy",
    "redis": "healthy",
    "payment_processor": "healthy"
  }
}
```

### システム統計

```http
GET /api/v1/system/stats
```

### 利用可能な決済方法

```http
GET /api/v1/payments/methods
```

#### レスポンス例

```json
{
  "success": true,
  "data": {
    "methods": [
      {
        "id": "stripe",
        "name": "クレジットカード (Stripe)",
        "description": "Visa, MasterCard, AMEX対応",
        "fee_percentage": 3.6,
        "min_amount": 100,
        "max_amount": 1000000,
        "currencies": ["JPY"],
        "processing_time": "即時"
      },
      {
        "id": "paypal",
        "name": "PayPal",
        "description": "PayPalアカウント決済",
        "fee_percentage": 3.9,
        "min_amount": 100,
        "max_amount": 1000000,
        "currencies": ["JPY"],
        "processing_time": "即時"
      },
      {
        "id": "bank_transfer",
        "name": "銀行振込",
        "description": "指定口座への振込",
        "fee_percentage": 0,
        "min_amount": 1000,
        "max_amount": 10000000,
        "currencies": ["JPY"],
        "processing_time": "1-3営業日"
      },
      {
        "id": "cash",
        "name": "現金支払い",
        "description": "当日会場での現金支払い",
        "fee_percentage": 0,
        "min_amount": 100,
        "max_amount": 100000,
        "currencies": ["JPY"],
        "processing_time": "当日"
      }
    ]
  }
}
```

## WebSocket API（リアルタイム通知）

### 接続エンドポイント

```
wss://your-domain.com/cable
```

### チャンネル一覧

#### 祭り更新通知

```javascript
consumer.subscriptions.create("FestivalChannel", {
  festival_id: 1,
  received(data) {
    // data.type: "payment_completed", "task_updated", "vendor_approved"
    // data.payload: 更新されたデータ
  }
});
```

#### システム通知

```javascript
consumer.subscriptions.create("SystemChannel", {
  received(data) {
    // システム全体の通知
  }
});
```

## SDK・ライブラリ

### JavaScript SDK

```bash
npm install festival-planner-sdk
```

```javascript
import FestivalPlatform from 'festival-planner-sdk';

const client = new FestivalPlatform({
  baseURL: 'https://your-domain.com/api/v1',
  apiToken: 'your-api-token'
});

// 祭り一覧取得
const festivals = await client.festivals.list();

// 決済作成
const payment = await client.payments.create(festivalId, {
  amount: 5000,
  payment_method: 'stripe',
  description: '出店料金'
});
```

### Ruby Gem

```ruby
gem 'festival_planner_client'
```

```ruby
require 'festival_planner_client'

client = FestivalPlannerClient.new(
  base_url: 'https://your-domain.com/api/v1',
  api_token: 'your-api-token'
)

# 祭り一覧取得
festivals = client.festivals.list

# 決済作成
payment = client.payments.create(festival_id, {
  amount: 5000,
  payment_method: 'stripe',
  description: '出店料金'
})
```

## 変更履歴

### v1.0.0 (2024-03-15)
- 初回リリース
- Festivals API実装
- Payments API実装
- Analytics API実装

---

## サポート

APIに関するご質問やサポートが必要な場合は、以下までお問い合わせください：

- **開発者サポート**: dev-support@your-domain.com
- **技術ドキュメント**: https://docs.your-domain.com
- **GitHub Issues**: https://github.com/your-org/festival-planner-platform/issues

このドキュメントは定期的に更新されます。最新版は [こちら](https://docs.your-domain.com/api) でご確認ください。