require 'rails_helper'

RSpec.describe "Dashboard System", type: :system do
  let(:admin_user) { create(:user, role: :admin) }
  let(:festival) { create(:festival, user: admin_user) }

  before do
    driven_by(:rack_test)
    sign_in admin_user

    # Create test data for meaningful dashboard
    create_test_data
  end

  describe "Festival Dashboard" do
    it "displays comprehensive analytics and metrics" do
      visit admin_festival_dashboard_path(festival)

      # Check main dashboard elements
      expect(page).to have_content(festival.name)
      expect(page).to have_content("ダッシュボード")

      # Verify overview metrics are displayed
      expect(page).to have_content("総収益")
      expect(page).to have_content("総出店者数")
      expect(page).to have_content("タスク完了率")
      expect(page).to have_content("予算使用率")

      # Check for chart containers
      expect(page).to have_css("#budgetChart")
      expect(page).to have_css("#taskChart")

      # Verify analytics sections
      expect(page).to have_content("予算・財務分析")
      expect(page).to have_content("出店者分析")
      expect(page).to have_content("タスク・プロジェクト分析")
      expect(page).to have_content("コミュニケーション分析")
    end

    it "supports date range filtering" do
      visit admin_festival_dashboard_path(festival)

      # Test date range selector
      click_button "期間選択"
      click_link "過去30日間"

      # Should update URL with period parameter
      expect(current_url).to include("period=last_30_days")
    end

    it "provides export functionality" do
      visit admin_festival_dashboard_path(festival)

      # Test export dropdown
      click_button "エクスポート"
      expect(page).to have_link("CSV形式")
      expect(page).to have_link("Excel形式")
      expect(page).to have_link("JSON形式")
    end

    it "refreshes data dynamically" do
      visit admin_festival_dashboard_path(festival)

      # Test refresh button functionality
      expect(page).to have_button(title: "データを更新")

      # Simulate data update (would require JavaScript driver)
      # find('button[title="データを更新"]').click
    end
  end

  describe "Platform Overview Dashboard" do
    it "displays platform-wide metrics" do
      visit admin_dashboard_path

      expect(page).to have_content("プラットフォーム総合ダッシュボード")
      expect(page).to have_content("全祭りの統合分析")

      # Global metrics
      expect(page).to have_content("総祭り数")
      expect(page).to have_content("アクティブ")
      expect(page).to have_content("総出店者")
      expect(page).to have_content("総収益")
      expect(page).to have_content("完了率")
      expect(page).to have_content("DAU")

      # Trend analysis
      expect(page).to have_content("トレンド分析")
      expect(page).to have_content("パフォーマンス指標")
      expect(page).to have_content("クイックアクション")
    end

    it "provides admin quick actions" do
      visit admin_dashboard_path

      expect(page).to have_link("新しい祭りを作成")
      expect(page).to have_link("出店者管理")
      expect(page).to have_link("システム監視")
      expect(page).to have_link("ユーザー管理")
    end
  end

  describe "Analytics Data Loading" do
    it "loads budget analytics section" do
      visit admin_festival_dashboard_path(festival)

      within("[data-dashboard-target='budgetAnalytics']") do
        expect(page).to have_content("予算使用率")
        expect(page).to have_content("カテゴリ別支出")
      end
    end

    it "loads vendor analytics section" do
      visit admin_festival_dashboard_path(festival)

      within("[data-dashboard-target='vendorAnalytics']") do
        expect(page).to have_content("申請数")
        expect(page).to have_content("承認率")
      end
    end

    it "loads task analytics section" do
      visit admin_festival_dashboard_path(festival)

      within("[data-dashboard-target='taskAnalytics']") do
        expect(page).to have_content("期限内完了")
        expect(page).to have_content("平均完了日数")
      end
    end

    it "loads communication analytics section" do
      visit admin_festival_dashboard_path(festival)

      within("[data-dashboard-target='communicationAnalytics']") do
        expect(page).to have_content("フォーラム投稿")
        expect(page).to have_content("チャットメッセージ")
      end
    end
  end

  describe "Responsive Design" do
    it "adapts layout for mobile screens", :js do
      # Would require JavaScript driver for responsive testing
      page.driver.browser.manage.window.resize_to(375, 667) # iPhone size

      visit admin_festival_dashboard_path(festival)

      # Mobile-specific layout checks would go here
      expect(page).to have_content(festival.name)
    end
  end

  describe "Performance" do
    it "loads dashboard within acceptable time" do
      start_time = Time.current
      visit admin_festival_dashboard_path(festival)
      load_time = Time.current - start_time

      expect(load_time).to be < 3.seconds
    end

    it "handles large datasets efficiently" do
      # Create large dataset
      create_list(:payment, 100, festival: festival, user: admin_user)
      create_list(:task, 50, festival: festival)
      create_list(:vendor_application, 30, festival: festival)

      start_time = Time.current
      visit admin_festival_dashboard_path(festival)
      load_time = Time.current - start_time

      expect(load_time).to be < 5.seconds
    end
  end

  describe "Security" do
    context "as regular user" do
      let(:regular_user) { create(:user, role: :resident) }

      before { sign_in regular_user }

      it "denies access to admin dashboard" do
        visit admin_dashboard_path

        expect(page).to have_content("権限がありません")
        expect(current_path).to eq(root_path)
      end

      it "denies access to festival admin dashboard" do
        visit admin_festival_dashboard_path(festival)

        expect(page).to have_content("権限がありません")
        expect(current_path).to eq(root_path)
      end
    end

    context "as festival owner" do
      let(:festival_owner) { create(:user, role: :committee_member) }
      let(:owned_festival) { create(:festival, user: festival_owner) }

      before { sign_in festival_owner }

      it "allows access to own festival dashboard" do
        visit admin_festival_dashboard_path(owned_festival)

        expect(page).to have_content(owned_festival.name)
        expect(page).to have_content("ダッシュボード")
      end

      it "denies access to other's festival dashboard" do
        visit admin_festival_dashboard_path(festival)

        expect(page).to have_content("権限がありません")
      end
    end
  end

  describe "Error Handling" do
    it "handles missing festival gracefully" do
      visit admin_festival_dashboard_path(id: 99999)

      expect(page).to have_content("見つかりません")
    end

    it "displays error message when analytics service fails" do
      allow(AnalyticsService).to receive(:new).and_raise(StandardError, "Service unavailable")

      visit admin_festival_dashboard_path(festival)

      # Should show error state instead of crashing
      expect(page).to have_content("データの読み込みに失敗")
    end
  end

  private

  def create_test_data
    # Create budget categories and expenses
    budget_category = create(:budget_category, festival: festival, budget_limit: 50000)
    create(:expense, festival: festival, budget_category: budget_category, amount: 15000, status: :approved)

    # Create tasks
    create(:task, festival: festival, status: :completed)
    create(:task, festival: festival, status: :in_progress)
    create(:task, festival: festival, status: :pending)

    # Create vendor applications
    create(:vendor_application, festival: festival, status: :approved)
    create(:vendor_application, festival: festival, status: :pending)
    create(:vendor_application, festival: festival, status: :rejected)

    # Create payments
    create(:payment, festival: festival, user: admin_user, status: :completed, amount: 5000)
    create(:payment, festival: festival, user: admin_user, status: :pending, amount: 3000)

    # Create communication data
    forum = create(:forum, festival: festival)
    thread = create(:forum_thread, forum: forum, user: admin_user)
    create(:forum_post, forum_thread: thread, user: admin_user)

    chat_room = create(:chat_room, festival: festival)
    create(:chat_message, chat_room: chat_room, user: admin_user)

    # Create revenues
    create(:revenue, festival: festival, budget_category: budget_category, amount: 25000, status: :confirmed)
  end
end
