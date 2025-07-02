# 出店申請ワークフロー設計書

## 概要
現在のシンプルな出店申請機能を、包括的なワークフロー管理システムに拡張します。

## 現状分析

### 既存機能
- ✅ 基本CRUD操作
- ✅ シンプルステータス管理 (pending/approved/rejected/cancelled)
- ✅ 通知システム統合
- ✅ 権限管理 (CanCanCan)
- ✅ レスポンシブUI

### 課題
- ❌ 管理者承認・却下操作なし
- ❌ 詳細なワークフロー管理なし
- ❌ 承認理由・コメント機能なし
- ❌ 一括操作機能なし
- ❌ 進捗追跡・履歴なし

## 新ワークフロー設計

### 1. 拡張ステータス定義

```ruby
enum :status, {
  draft: 0,           # 下書き（未提出）
  submitted: 1,       # 提出済み（審査待ち）
  under_review: 2,    # 審査中
  requires_changes: 3, # 修正要求
  conditionally_approved: 4, # 条件付き承認
  approved: 5,        # 承認
  rejected: 6,        # 却下
  withdrawn: 7,       # 申請者による取り下げ
  cancelled: 8        # システムによるキャンセル
}
```

### 2. ワークフロー状態遷移

```
draft → submitted → under_review → [approved|rejected|requires_changes|conditionally_approved]
                         ↑               ↓
                    requires_changes ←──┘
                         ↓
                      submitted (再提出)
```

### 3. 新しいモデル設計

#### ApplicationReview モデル
```ruby
class ApplicationReview < ApplicationRecord
  belongs_to :vendor_application
  belongs_to :reviewer, class_name: 'User'
  
  enum :action, {
    submitted: 0,
    started_review: 1,
    requested_changes: 2,
    conditionally_approved: 3,
    approved: 4,
    rejected: 5,
    withdrawn: 6
  }
  
  validates :comment, presence: true, if: -> { rejected? || requested_changes? }
  validates :conditions, presence: true, if: :conditionally_approved?
end
```

#### ApplicationComment モデル
```ruby
class ApplicationComment < ApplicationRecord
  belongs_to :vendor_application
  belongs_to :user
  
  validates :content, presence: true, length: { maximum: 1000 }
  
  scope :public, -> { where(internal: false) }
  scope :internal, -> { where(internal: true) }
end
```

### 4. 管理機能

#### 管理者ダッシュボード
- 審査待ち申請一覧
- 審査中申請一覧
- 承認・却下・修正要求ボタン
- 一括操作機能
- 審査期限アラート

#### 審査機能
- 申請詳細レビュー画面
- コメント・条件入力
- ステータス変更履歴表示
- 申請者とのコミュニケーション

### 5. 通知システム拡張

#### 新しい通知タイプ
- `application_submitted` - 申請提出時 (管理者向け)
- `review_started` - 審査開始時 (申請者向け)
- `changes_requested` - 修正要求時 (申請者向け)
- `conditionally_approved` - 条件付き承認時 (申請者向け)
- `application_approved` - 承認時 (申請者向け)
- `application_rejected` - 却下時 (申請者向け)
- `review_deadline_approaching` - 審査期限間近 (管理者向け)

### 6. UI/UX改善

#### 申請者向け
- 進捗表示バー
- ステータス別アクションボタン
- コメント・履歴表示
- 修正要求への対応画面

#### 管理者向け
- 審査ダッシュボード
- 申請一覧・フィルタリング
- 一括操作機能
- 審査画面

## 実装フェーズ

### Phase 1: データモデル拡張
1. マイグレーション作成
2. モデル関連追加
3. バリデーション実装

### Phase 2: 管理者機能
1. 審査ダッシュボード
2. 申請審査画面
3. 一括操作機能

### Phase 3: ワークフロー統合
1. ステータス遷移ロジック
2. 通知システム拡張
3. 権限管理更新

### Phase 4: UI/UX改善
1. 進捗表示
2. コメント機能
3. 履歴表示

## 技術要件

### 必要なGem
- `aasm` - 状態遷移管理
- `acts_as_commentable` または独自実装

### データベース変更
- `application_reviews` テーブル追加
- `application_comments` テーブル追加
- `vendor_applications` テーブル拡張

### テスト要件
- ワークフロー状態遷移テスト
- 権限管理テスト
- 通知システムテスト
- 統合テスト

## 成功指標
- 管理者の審査効率向上
- 申請者の進捗把握向上
- 審査プロセスの透明性確保
- システムの使いやすさ向上