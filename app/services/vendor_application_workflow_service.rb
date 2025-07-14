class VendorApplicationWorkflowService
  def self.process_deadline_checks
    new.process_deadline_checks
  end

  def self.generate_workflow_analytics(date_range = 30.days.ago..Time.current)
    new.generate_workflow_analytics(date_range)
  end

  def self.auto_assign_reviewers
    new.auto_assign_reviewers
  end

  def process_deadline_checks
    check_submission_deadlines
    check_review_deadlines
    escalate_overdue_reviews
    send_deadline_reminders
  end

  def generate_workflow_analytics(date_range)
    applications = VendorApplication.where(created_at: date_range)

    {
      overview: generate_overview_stats(applications),
      performance_metrics: generate_performance_metrics(applications),
      workflow_efficiency: generate_workflow_efficiency(applications),
      bottleneck_analysis: analyze_workflow_bottlenecks(applications),
      reviewer_performance: analyze_reviewer_performance(applications, date_range),
      prediction_metrics: generate_prediction_metrics(applications)
    }
  end

  def auto_assign_reviewers
    pending_applications = VendorApplication.submitted.where(assigned_reviewer_id: nil)

    pending_applications.find_each do |application|
      reviewer = find_best_reviewer_for(application)
      if reviewer
        assign_reviewer(application, reviewer)
      end
    end
  end

  def bulk_process_applications(application_ids, action, params = {})
    results = {
      success_count: 0,
      error_count: 0,
      errors: []
    }

    application_ids.each do |id|
      begin
        application = VendorApplication.find(id)

        case action.to_s
        when "approve"
          if application.approve!(params[:reviewer], params[:comment])
            results[:success_count] += 1
          else
            results[:error_count] += 1
            results[:errors] << "Application #{id}: Cannot approve"
          end
        when "reject"
          if params[:comment].present? && application.reject!(params[:reviewer], params[:comment])
            results[:success_count] += 1
          else
            results[:error_count] += 1
            results[:errors] << "Application #{id}: Cannot reject or missing comment"
          end
        when "request_changes"
          if params[:comment].present? && application.request_changes!(params[:reviewer], params[:comment])
            results[:success_count] += 1
          else
            results[:error_count] += 1
            results[:errors] << "Application #{id}: Cannot request changes or missing comment"
          end
        when "start_review"
          if application.start_review!(params[:reviewer])
            results[:success_count] += 1
          else
            results[:error_count] += 1
            results[:errors] << "Application #{id}: Cannot start review"
          end
        else
          results[:error_count] += 1
          results[:errors] << "Application #{id}: Unknown action #{action}"
        end
      rescue ActiveRecord::RecordNotFound
        results[:error_count] += 1
        results[:errors] << "Application #{id}: Not found"
      rescue => error
        results[:error_count] += 1
        results[:errors] << "Application #{id}: #{error.message}"
      end
    end

    results
  end

  def generate_application_timeline(application)
    events = []

    # 申請作成
    events << {
      type: "created",
      timestamp: application.created_at,
      actor: application.user.display_name,
      description: "申請を作成しました",
      icon: "plus-circle",
      color: "primary"
    }

    # レビューイベント
    application.application_reviews.order(:created_at).each do |review|
      events << {
        type: review.action,
        timestamp: review.reviewed_at || review.created_at,
        actor: review.reviewer.display_name,
        description: review.action_text,
        comment: review.comment,
        conditions: review.conditions,
        icon: review_icon(review.action),
        color: review_color(review.action)
      }
    end

    # コメントイベント
    application.application_comments.order(:created_at).each do |comment|
      events << {
        type: "comment",
        timestamp: comment.created_at,
        actor: comment.user.display_name,
        description: comment.internal? ? "内部コメントを追加" : "コメントを追加",
        comment: comment.content,
        icon: "message-circle",
        color: comment.internal? ? "warning" : "info"
      }
    end

    # ファイルアップロードイベント
    if application.documents.attached?
      application.documents.attachments.each do |attachment|
        events << {
          type: "file_upload",
          timestamp: attachment.created_at,
          actor: application.user.display_name,
          description: "ファイルをアップロード: #{attachment.filename}",
          icon: "upload",
          color: "success"
        }
      end
    end

    events.sort_by { |event| event[:timestamp] }
  end

  def calculate_application_score(application)
    score = 0

    # 基本情報の完成度 (最大30点)
    score += 10 if application.business_name.present?
    score += 10 if application.business_type.present?
    score += 10 if application.description.present? && application.description.length >= 100

    # 添付書類の完成度 (最大20点)
    score += 10 if application.business_license.attached?
    score += 10 if application.documents.attached?

    # 申請の詳細度 (最大30点)
    score += 15 if application.requirements.present? && application.requirements.length >= 50
    score += 15 if application.expected_revenue.present? && application.expected_revenue > 0

    # 申請の迅速性 (最大20点)
    if application.festival.present?
      days_before_deadline = (application.festival.start_date - application.created_at.to_date).to_i
      if days_before_deadline > 60
        score += 20
      elsif days_before_deadline > 30
        score += 15
      elsif days_before_deadline > 7
        score += 10
      else
        score += 5
      end
    end

    [ score, 100 ].min
  end

  def suggest_reviewer_actions(application)
    suggestions = []
    score = calculate_application_score(application)

    if score >= 80
      suggestions << {
        action: "approve",
        priority: "high",
        reason: "申請内容が非常に充実しており、承認を推奨します",
        confidence: 0.9
      }
    elsif score >= 60
      suggestions << {
        action: "conditionally_approve",
        priority: "medium",
        reason: "申請内容は良好ですが、いくつかの条件付きで承認を検討してください",
        confidence: 0.7
      }
    elsif score >= 40
      suggestions << {
        action: "request_changes",
        priority: "medium",
        reason: "申請内容に不足があります。修正要求を推奨します",
        confidence: 0.8
      }
    else
      suggestions << {
        action: "reject",
        priority: "low",
        reason: "申請内容が不十分です。却下を検討してください",
        confidence: 0.6
      }
    end

    # 期限に基づく追加提案
    if application.review_overdue?
      suggestions << {
        action: "urgent_review",
        priority: "urgent",
        reason: "審査期限を過ぎています。緊急対応が必要です",
        confidence: 1.0
      }
    end

    suggestions
  end

  private

  def check_submission_deadlines
    # 提出期限が近い未提出の申請をチェック
    upcoming_deadline = VendorApplication.draft
                                        .where("submission_deadline <= ?", 3.days.from_now)
                                        .where("submission_deadline > ?", Time.current)

    upcoming_deadline.find_each do |application|
      send_submission_deadline_reminder(application)
    end

    # 提出期限を過ぎた申請をチェック
    overdue_submissions = VendorApplication.draft
                                          .where("submission_deadline < ?", Time.current)

    overdue_submissions.find_each do |application|
      mark_submission_overdue(application)
    end
  end

  def check_review_deadlines
    # 審査期限が近い申請をチェック
    upcoming_review_deadline = VendorApplication.where(status: [ :submitted, :under_review ])
                                               .where("review_deadline <= ?", 3.days.from_now)
                                               .where("review_deadline > ?", Time.current)

    upcoming_review_deadline.find_each do |application|
      send_review_deadline_reminder(application)
    end
  end

  def escalate_overdue_reviews
    # 審査期限を過ぎた申請をエスカレーション
    overdue_reviews = VendorApplication.where(status: [ :submitted, :under_review ])
                                      .where("review_deadline < ?", Time.current)

    overdue_reviews.find_each do |application|
      escalate_to_senior_reviewer(application)
    end
  end

  def send_deadline_reminders
    # 各種期限のリマインダーを送信
    send_daily_summary_to_admins
  end

  def generate_overview_stats(applications)
    total = applications.count
    return {} if total.zero?

    {
      total_applications: total,
      status_distribution: applications.group(:status).count,
      approval_rate: calculate_approval_rate(applications),
      average_processing_time: calculate_average_processing_time(applications),
      applications_by_month: applications.group_by_month(:created_at).count
    }
  end

  def generate_performance_metrics(applications)
    {
      fastest_approval: find_fastest_approval(applications),
      slowest_approval: find_slowest_approval(applications),
      most_reviewed_application: find_most_reviewed_application(applications),
      average_score: applications.average { |app| calculate_application_score(app) }
    }
  end

  def generate_workflow_efficiency(applications)
    total_steps = 0
    total_applications = 0

    applications.where.not(status: :draft).find_each do |app|
      steps = app.application_reviews.count
      total_steps += steps
      total_applications += 1
    end

    {
      average_workflow_steps: total_applications > 0 ? (total_steps.to_f / total_applications).round(2) : 0,
      workflow_completion_rate: calculate_workflow_completion_rate(applications),
      bottleneck_stages: identify_bottleneck_stages(applications)
    }
  end

  def analyze_workflow_bottlenecks(applications)
    stage_times = {}

    applications.includes(:application_reviews).find_each do |app|
      reviews = app.application_reviews.order(:created_at)

      reviews.each_cons(2) do |current, next_review|
        stage = "#{current.action}_to_#{next_review.action}"
        time_diff = (next_review.created_at - current.created_at) / 1.day

        stage_times[stage] ||= []
        stage_times[stage] << time_diff
      end
    end

    stage_times.transform_values do |times|
      {
        average_days: (times.sum / times.length).round(2),
        max_days: times.max.round(2),
        min_days: times.min.round(2),
        count: times.length
      }
    end
  end

  def analyze_reviewer_performance(applications, date_range)
    reviewer_stats = {}

    applications.joins(:application_reviews)
               .where(application_reviews: { created_at: date_range })
               .includes(:application_reviews)
               .find_each do |app|
      app.application_reviews.each do |review|
        next unless review.created_at.in?(date_range)

        reviewer_id = review.reviewer_id
        reviewer_stats[reviewer_id] ||= {
          name: review.reviewer.display_name,
          total_reviews: 0,
          approvals: 0,
          rejections: 0,
          change_requests: 0,
          average_time: []
        }

        reviewer_stats[reviewer_id][:total_reviews] += 1

        case review.action
        when "approved"
          reviewer_stats[reviewer_id][:approvals] += 1
        when "rejected"
          reviewer_stats[reviewer_id][:rejections] += 1
        when "requested_changes"
          reviewer_stats[reviewer_id][:change_requests] += 1
        end

        if app.reviewed?
          processing_time = (app.reviewed_at - app.created_at) / 1.day
          reviewer_stats[reviewer_id][:average_time] << processing_time
        end
      end
    end

    # 平均時間を計算
    reviewer_stats.each do |id, stats|
      if stats[:average_time].any?
        stats[:average_processing_time] = (stats[:average_time].sum / stats[:average_time].length).round(2)
      else
        stats[:average_processing_time] = 0
      end
      stats.delete(:average_time)
    end

    reviewer_stats
  end

  def generate_prediction_metrics(applications)
    recent_applications = applications.where("created_at >= ?", 30.days.ago)
    return {} if recent_applications.count < 10

    {
      predicted_approval_rate: predict_approval_rate(recent_applications),
      estimated_processing_time: estimate_processing_time(recent_applications),
      capacity_utilization: calculate_capacity_utilization(recent_applications)
    }
  end

  def find_best_reviewer_for(application)
    # 利用可能な審査者を取得
    available_reviewers = User.where(role: [ :admin, :committee_member, :system_admin ])
                             .where.not(id: application.user_id)

    # 現在の作業負荷を考慮
    reviewer_workloads = available_reviewers.map do |reviewer|
      current_workload = VendorApplication.where(assigned_reviewer: reviewer)
                                         .where(status: [ :submitted, :under_review ])
                                         .count

      {
        reviewer: reviewer,
        workload: current_workload,
        specialization_match: calculate_specialization_match(reviewer, application)
      }
    end

    # 最適な審査者を選択（作業負荷と専門性のバランス）
    reviewer_workloads.min_by do |item|
      workload_weight = item[:workload] * 2
      specialization_weight = (1 - item[:specialization_match]) * 3
      workload_weight + specialization_weight
    end&.dig(:reviewer)
  end

  def assign_reviewer(application, reviewer)
    application.update!(assigned_reviewer: reviewer)

    # 通知を送信
    NotificationService.create_notification(
      user: reviewer,
      type: "application_assigned",
      title: "新しい申請が割り当てられました",
      message: "「#{application.business_name}」の審査が割り当てられました",
      related_object: application
    )
  end

  def calculate_specialization_match(reviewer, application)
    # 審査者の専門分野と申請内容のマッチング度を計算
    # 簡単な実装例（実際はより複雑なロジックが必要）
    0.5 # デフォルト値
  end

  def calculate_approval_rate(applications)
    total = applications.count
    return 0 if total.zero?

    approved = applications.approved.count
    (approved.to_f / total * 100).round(2)
  end

  def calculate_average_processing_time(applications)
    processed = applications.where.not(reviewed_at: nil)
    return 0 if processed.empty?

    total_time = processed.sum { |app| (app.reviewed_at - app.created_at) / 1.day }
    (total_time / processed.count).round(2)
  end

  def send_submission_deadline_reminder(application)
    NotificationService.create_notification(
      user: application.user,
      type: "submission_deadline_reminder",
      title: "申請提出期限が近づいています",
      message: "「#{application.business_name}」の提出期限まで残り#{days_until(application.submission_deadline)}日です",
      related_object: application
    )
  end

  def send_review_deadline_reminder(application)
    if application.assigned_reviewer
      NotificationService.create_notification(
        user: application.assigned_reviewer,
        type: "review_deadline_reminder",
        title: "審査期限が近づいています",
        message: "「#{application.business_name}」の審査期限まで残り#{days_until(application.review_deadline)}日です",
        related_object: application
      )
    end
  end

  def escalate_to_senior_reviewer(application)
    senior_reviewers = User.where(role: [ :admin, :system_admin ])

    senior_reviewers.each do |reviewer|
      NotificationService.create_notification(
        user: reviewer,
        type: "review_escalation",
        title: "審査期限超過のエスカレーション",
        message: "「#{application.business_name}」の審査が期限を超過しています",
        related_object: application
      )
    end
  end

  def send_daily_summary_to_admins
    admins = User.where(role: [ :admin, :system_admin ])

    summary_data = {
      pending_reviews: VendorApplication.submitted.count,
      overdue_reviews: VendorApplication.joins(:festival)
                                       .where("vendor_applications.review_deadline < ?", Time.current)
                                       .where(status: [ :submitted, :under_review ]).count,
      new_applications: VendorApplication.where("created_at >= ?", 1.day.ago).count
    }

    admins.each do |admin|
      NotificationService.create_notification(
        user: admin,
        type: "daily_admin_summary",
        title: "申請管理 日次サマリー",
        message: "新規申請: #{summary_data[:new_applications]}件、保留中: #{summary_data[:pending_reviews]}件、期限超過: #{summary_data[:overdue_reviews]}件",
        metadata: summary_data
      )
    end
  end

  def days_until(date)
    return 0 unless date
    [ (date.to_date - Date.current).to_i, 0 ].max
  end

  def review_icon(action)
    case action
    when "submitted" then "send"
    when "started_review" then "eye"
    when "approved" then "check-circle"
    when "rejected" then "x-circle"
    when "requested_changes" then "edit"
    when "conditionally_approved" then "check-circle-2"
    when "withdrawn" then "arrow-left"
    else "circle"
    end
  end

  def review_color(action)
    case action
    when "submitted" then "primary"
    when "started_review" then "warning"
    when "approved" then "success"
    when "rejected" then "danger"
    when "requested_changes" then "warning"
    when "conditionally_approved" then "info"
    when "withdrawn" then "secondary"
    else "secondary"
    end
  end

  def mark_submission_overdue(application)
    # 提出期限超過のマーキング処理
    application.update(submission_overdue: true)
  end

  def find_fastest_approval(applications)
    approved_apps = applications.approved.where.not(reviewed_at: nil)
    return nil if approved_apps.empty?

    approved_apps.min_by { |app| app.reviewed_at - app.created_at }
  end

  def find_slowest_approval(applications)
    approved_apps = applications.approved.where.not(reviewed_at: nil)
    return nil if approved_apps.empty?

    approved_apps.max_by { |app| app.reviewed_at - app.created_at }
  end

  def find_most_reviewed_application(applications)
    applications.left_joins(:application_reviews)
                .group("vendor_applications.id")
                .order("COUNT(application_reviews.id) DESC")
                .first
  end

  def calculate_workflow_completion_rate(applications)
    total = applications.count
    return 0 if total.zero?

    completed = applications.where(status: [ :approved, :rejected, :withdrawn, :cancelled ]).count
    (completed.to_f / total * 100).round(2)
  end

  def identify_bottleneck_stages(applications)
    # ワークフローのボトルネック段階を特定
    stage_counts = applications.joins(:application_reviews)
                              .group("application_reviews.action")
                              .count

    stage_counts.sort_by { |stage, count| -count }.first(3)
  end

  def predict_approval_rate(applications)
    # 機械学習的なアプローチの簡単な実装
    recent_approval_rate = calculate_approval_rate(applications)
    # 実際の実装では、より複雑な予測モデルを使用
    recent_approval_rate
  end

  def estimate_processing_time(applications)
    # 処理時間の推定
    calculate_average_processing_time(applications)
  end

  def calculate_capacity_utilization(applications)
    # 審査能力の利用率を計算
    active_reviewers = User.where(role: [ :admin, :committee_member, :system_admin ]).count
    pending_applications = VendorApplication.where(status: [ :submitted, :under_review ]).count

    return 0 if active_reviewers.zero?

    # 1人の審査者が同時に扱える申請数を5件と仮定
    max_capacity = active_reviewers * 5
    (pending_applications.to_f / max_capacity * 100).round(2)
  end
end
