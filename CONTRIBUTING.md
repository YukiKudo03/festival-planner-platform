# Contributing to Festival Planner Platform

[![Contributors Welcome](https://img.shields.io/badge/contributors-welcome-brightgreen.svg)](https://github.com/YukiKudo03/festival-planner-platform)
[![Test Quality](https://img.shields.io/badge/test%20quality-excellent-blue.svg)](https://github.com/YukiKudo03/festival-planner-platform)
[![Technical Debt](https://img.shields.io/badge/technical%20debt-eliminated-green.svg)](https://github.com/YukiKudo03/festival-planner-platform)

## 🎉 はじめに

Festival Planner Platformへの貢献に興味を持っていただき、ありがとうございます！このプロジェクトは、日本の伝統的な祭り文化を現代技術で支援し、世界に発信することを目的としています。

**現在のプロジェクト状況**:
- ✅ **7フェーズ完了**: 基盤から本番インフラまで完全実装
- ✅ **技術的負債完全除去**: 22/22 ペンディングテスト解決
- ✅ **本番レディ**: 包括的なテスト・セキュリティ・監視システム
- ✅ **87機能実装済み**: 企業レベルの機能完備

皆様のご貢献により、さらに優秀なプラットフォームを構築できます。

## 🌟 貢献の方法

### 1. イシューの報告
バグや機能要望がある場合は、GitHubのIssueを作成してください。

#### バグレポート
```markdown
## バグの概要
簡潔にバグの内容を説明してください。

## 再現手順
1. ...
2. ...
3. ...

## 期待される動作
正常に動作した場合の期待値を記載してください。

## 実際の動作
実際に起こった動作を記載してください。

## 環境情報
- OS: [e.g. macOS 14.0]
- ブラウザ: [e.g. Chrome 120]
- バージョン: [e.g. v1.0.0]

## スクリーンショット
該当する場合は、スクリーンショットを添付してください。
```

#### 機能要望
```markdown
## 機能要望の概要
実装したい機能の概要を説明してください。

## 解決したい問題
この機能によってどのような問題が解決されるかを説明してください。

## 提案する解決策
どのような機能実装を想定しているかを記載してください。

## 代替案
他に考えられる解決方法があれば記載してください。

## 追加情報
その他、参考になる情報があれば記載してください。
```

### 2. プルリクエスト

#### 前準備
```bash
# フォークしたリポジトリをクローン
git clone https://github.com/YOUR_USERNAME/festival-planner-platform.git
cd festival-planner-platform

# アップストリームリポジトリを追加
git remote add upstream https://github.com/ORIGINAL_OWNER/festival-planner-platform.git

# 最新の変更を取得
git fetch upstream
git checkout main
git merge upstream/main
```

#### ブランチ作成
```bash
# 機能ブランチの作成
git checkout -b feature/new-awesome-feature

# または、バグ修正ブランチの作成
git checkout -b fix/bug-description
```

#### 開発環境のセットアップ
```bash
# 依存関係のインストール
bundle install
npm install

# データベースのセットアップ
rails db:create db:migrate db:seed

# テストの実行
bundle exec rspec
```

#### コード作成
1. **コーディング規約**に従ってコードを作成
2. 適切な**テスト**を追加
3. **ドキュメント**を更新（必要に応じて）

#### プルリクエストの作成
```markdown
## 変更内容
このプルリクエストで何を変更したかを説明してください。

## 関連Issue
Fixes #(issue number)

## 変更の種類
- [ ] バグ修正
- [ ] 新機能
- [ ] 破壊的変更
- [ ] ドキュメント更新

## テスト
- [ ] 既存のテストが全て通ることを確認
- [ ] 新しいテストを追加
- [ ] 手動テストを実施

## チェックリスト
- [ ] コードがプロジェクトのスタイルガイドに従っている
- [ ] セルフレビューを実施
- [ ] コードにコメントを追加（複雑な箇所）
- [ ] ドキュメントを更新
- [ ] 変更によって新しい警告が発生しない
```

## 📋 開発ガイドライン

### コーディング規約

#### Ruby/Rails
```ruby
# 良い例
class FestivalController < ApplicationController
  before_action :authenticate_user!
  before_action :set_festival, only: [:show, :edit, :update, :destroy]
  
  def create
    @festival = current_user.festivals.build(festival_params)
    
    if @festival.save
      redirect_to @festival, notice: '祭りが作成されました。'
    else
      render :new, status: :unprocessable_entity
    end
  end
  
  private
  
  def festival_params
    params.require(:festival).permit(:name, :description, :start_date, :end_date)
  end
end
```

#### JavaScript
```javascript
// 良い例
class DashboardManager {
  constructor(options = {}) {
    this.element = options.element;
    this.apiUrl = options.apiUrl;
    this.updateInterval = options.updateInterval || 30000;
    
    this.init();
  }
  
  async init() {
    try {
      await this.loadData();
      this.startAutoUpdate();
    } catch (error) {
      console.error('Dashboard initialization failed:', error);
    }
  }
  
  async loadData() {
    const response = await fetch(this.apiUrl);
    const data = await response.json();
    
    this.renderDashboard(data);
  }
}
```

#### CSS/SCSS
```scss
// 良い例
.festival-card {
  background-color: $white;
  border-radius: $border-radius-lg;
  box-shadow: $box-shadow-sm;
  padding: $spacing-lg;
  margin-bottom: $spacing-md;
  
  &:hover {
    box-shadow: $box-shadow-md;
    transform: translateY(-2px);
    transition: all 0.3s ease;
  }
  
  .festival-card__title {
    color: $primary-color;
    font-size: $font-size-lg;
    font-weight: $font-weight-bold;
    margin-bottom: $spacing-sm;
  }
}
```

### テストガイドライン

#### RSpecテスト
```ruby
# spec/models/festival_spec.rb
RSpec.describe Festival, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:start_date) }
    it { should validate_presence_of(:end_date) }
  end
  
  describe 'associations' do
    it { should belong_to(:user) }
    it { should have_many(:vendor_applications) }
    it { should have_many(:payments) }
  end
  
  describe '#duration_days' do
    let(:festival) { build(:festival, start_date: Date.current, end_date: Date.current + 2.days) }
    
    it 'calculates duration correctly' do
      expect(festival.duration_days).to eq(3)
    end
  end
end
```

#### システムテスト
```ruby
# spec/system/festival_management_spec.rb
RSpec.describe 'Festival Management', type: :system do
  let(:user) { create(:user) }
  
  before do
    sign_in user
  end
  
  it 'allows user to create a new festival' do
    visit new_festival_path
    
    fill_in '祭り名', with: 'テスト祭り'
    fill_in '説明', with: 'テスト用の祭りです'
    fill_in '開始日', with: Date.current + 1.month
    fill_in '終了日', with: Date.current + 1.month + 2.days
    
    click_button '祭りを作成'
    
    expect(page).to have_content('祭りが作成されました')
    expect(page).to have_content('テスト祭り')
  end
end
```

### データベース設計

#### マイグレーション
```ruby
# 良い例
class CreateVendorApplications < ActiveRecord::Migration[7.0]
  def change
    create_table :vendor_applications do |t|
      t.references :festival, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :business_name, null: false
      t.text :description
      t.string :category, null: false
      t.string :status, default: 'pending', null: false
      t.decimal :proposed_fee, precision: 10, scale: 2
      t.jsonb :contact_info, null: false, default: {}
      t.timestamps
    end
    
    add_index :vendor_applications, [:festival_id, :status]
    add_index :vendor_applications, :category
  end
end
```

### API設計

#### RESTful API
```ruby
# app/controllers/api/v1/festivals_controller.rb
module Api
  module V1
    class FestivalsController < BaseController
      def index
        festivals = current_user.accessible_festivals
                                .includes(:user, :venue)
                                .page(params[:page])
                                .per(params[:per_page] || 25)
        
        render json: {
          success: true,
          data: festivals.map { |f| FestivalSerializer.new(f).as_json },
          meta: pagination_meta(festivals)
        }
      end
      
      def create
        festival = current_user.festivals.build(festival_params)
        
        if festival.save
          render json: {
            success: true,
            data: FestivalSerializer.new(festival).as_json,
            message: '祭りが作成されました'
          }, status: :created
        else
          render json: {
            success: false,
            errors: festival.errors.full_messages
          }, status: :unprocessable_entity
        end
      end
      
      private
      
      def festival_params
        params.require(:festival).permit(:name, :description, :start_date, :end_date, :location, :budget, :capacity, :public)
      end
    end
  end
end
```

## 🎯 開発フロー

### Git ワークフロー

#### ブランチ命名規則
- `feature/feature-name` - 新機能
- `fix/bug-description` - バグ修正
- `docs/documentation-update` - ドキュメント更新
- `refactor/code-improvement` - リファクタリング
- `test/test-addition` - テスト追加

#### コミットメッセージ
```bash
# 良い例
git commit -m "Add payment status validation to Payment model

- Validate status transitions from pending to completed
- Add custom error messages for invalid transitions
- Update existing tests to cover new validation rules

Fixes #123"
```

#### プルリクエストフロー
1. Issue作成 → 2. ブランチ作成 → 3. 開発 → 4. テスト → 5. PR作成 → 6. コードレビュー → 7. マージ

### コードレビュー

#### レビューのポイント
- **機能性**: 要件を満たしているか
- **可読性**: コードが理解しやすいか
- **保守性**: 将来の変更に対応できるか
- **性能**: パフォーマンスに問題はないか
- **セキュリティ**: セキュリティ上の問題はないか
- **テスト**: 適切なテストが含まれているか

#### レビューコメント例
```markdown
## 良いコメント例

### 提案
この部分は`find_by`の代わりに`find_by!`を使用することで、
レコードが見つからない場合の例外処理を明確にできます。

### 質問
この条件分岐の意図を教えてください。コメントを追加していただけますか？

### 褒める
エラーハンドリングが丁寧に実装されていて素晴らしいです！

### 提案（セキュリティ）
ユーザー入力をそのまま使用すると XSS の危険性があります。
`sanitize`メソッドの使用を検討してください。
```

## 🏷️ ラベルとマイルストーン

### Issue ラベル
- `bug` - バグ報告
- `enhancement` - 機能改善
- `feature` - 新機能
- `documentation` - ドキュメント
- `good first issue` - 初心者向け
- `help wanted` - ヘルプ募集
- `priority: high` - 高優先度
- `priority: medium` - 中優先度
- `priority: low` - 低優先度

### マイルストーン
- `v1.1.0` - 次期マイナーリリース
- `v2.0.0` - 次期メジャーリリース
- `Backlog` - 将来検討事項

## 🎖️ 貢献者認定

### レベル別貢献者

#### Contributor (貢献者)
- 1つ以上のPRがマージされた方
- IssueやDiscussionで有益な情報を提供した方

#### Regular Contributor (常連貢献者)
- 5つ以上のPRがマージされた方
- 継続的にプロジェクトに参加している方

#### Core Contributor (コア貢献者)
- 20つ以上のPRがマージされた方
- レビューやメンタリングを積極的に行う方
- プロジェクトの方向性に関わる議論に参加する方

#### Maintainer (メンテナー)
- 長期間にわたってプロジェクトをリードする方
- コミュニティの運営に積極的に関わる方

### 特別な貢献

#### 🏆 Festival Hero Award
- 年間を通じて最も多くの貢献をした方

#### 🎨 Design Excellence Award  
- UI/UXの向上に大きく貢献した方

#### 🔧 Technical Innovation Award
- 技術的な革新やパフォーマンス改善に貢献した方

#### 📚 Documentation Master Award
- ドキュメントの改善に大きく貢献した方

#### 🤝 Community Builder Award
- コミュニティの発展に貢献した方

## 📞 コミュニケーション

### 連絡方法
- **GitHub Issues**: バグ報告・機能要望
- **GitHub Discussions**: 一般的な議論・質問
- **Discord**: リアルタイムチャット（リンクは後日公開）
- **メール**: contact@festival-planner.dev

### 行動規範
私たちは、すべての参加者にとって安全で歓迎される環境を提供することをお約束します。

#### 期待される行動
- 他者への敬意と親切さ
- 建設的なフィードバック
- 多様性と包括性の尊重
- 学習と成長への意欲

#### 受け入れられない行動
- ハラスメントや差別的言動
- 攻撃的または侮辱的なコメント
- 個人情報の暴露
- その他、専門的でない行動

### 質問とサポート
- **初心者向け**: `good first issue`ラベルの付いたIssueから始めることをお勧めします
- **技術的質問**: GitHub Discussionsをご利用ください
- **セキュリティ問題**: security@festival-planner.dev まで直接ご連絡ください

## 🌍 国際化対応

### 翻訳への貢献
現在、以下の言語での翻訳を募集しています：
- English
- 中文 (Chinese)
- 한국어 (Korean)
- Français (French)
- Español (Spanish)

### 翻訳の手順
1. `config/locales/`ディレクトリの既存ファイルを参照
2. 新しい言語ファイルを作成（例：`fr.yml`）
3. キーを保持して値を翻訳
4. 翻訳の品質確認とテスト

## 🎉 最後に

Festival Planner Platformは、コミュニティの力によって成長するプロジェクトです。技術的なスキルレベルに関係なく、すべての貢献を歓迎します。

- **初心者の方**: 小さなバグ修正やドキュメント改善から始めてください
- **経験者の方**: 新機能の実装やアーキテクチャの改善をお願いします
- **デザイナーの方**: UI/UXの改善提案をお待ちしています
- **ライターの方**: ドキュメントやコンテンツの改善にご協力ください

皆様の貢献により、日本の祭り文化を世界に発信し、次世代に継承していくプラットフォームを作り上げていきましょう！

---

**ハッピーコーディング！🎊**

貢献に関するご質問がございましたら、お気軽にお問い合わせください。私たちはいつでもサポートいたします。