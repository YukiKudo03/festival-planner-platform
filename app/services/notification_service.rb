class NotificationService
  def self.create_notification(params)
    notification = Notification.create!(params)

    # 通知設定を確認してメール送信
    setting = notification.recipient.notification_setting_for(notification.notification_type)

    if setting.should_send_email? && setting.should_send_immediately?
      NotificationMailer.send_notification(notification).deliver_later
    end

    # Web通知（リアルタイム）
    if setting.should_send_web? && setting.should_send_immediately?
      broadcast_notification(notification)
    end

    # LINE通知
    if setting.should_send_line? && setting.should_send_immediately?
      send_line_notification(notification)
    end

    notification
  end

  def self.send_task_deadline_reminder(task)
    task.festival.tasks.joins(:user).includes(:user).each do |festival_task|
      next unless festival_task.user != task.user # 自分以外に通知

      create_notification(
        recipient: festival_task.user,
        sender: nil, # システム通知
        notifiable: task,
        notification_type: "task_deadline_reminder",
        title: "タスクの期限が近づいています",
        message: "「#{task.title}」の期限（#{task.due_date.strftime('%Y年%m月%d日')}）が近づいています。"
      )
    end
  end

  def self.send_task_overdue_notification(task)
    create_notification(
      recipient: task.user,
      sender: nil,
      notifiable: task,
      notification_type: "task_overdue",
      title: "タスクが期限切れになりました",
      message: "「#{task.title}」が期限切れになりました。確認をお願いします。"
    )
  end

  def self.send_task_assigned_notification(task, sender)
    create_notification(
      recipient: task.user,
      sender: sender,
      notifiable: task,
      notification_type: "task_assigned",
      title: "新しいタスクが割り当てられました",
      message: "「#{task.title}」があなたに割り当てられました。"
    )
  end

  def self.send_task_status_changed_notification(task, old_status)
    # タスクに関連する人に通知（お祭りの関係者など）
    task.festival.tasks.joins(:user).includes(:user).map(&:user).uniq.each do |user|
      next if user == task.user # 実行者には通知しない

      create_notification(
        recipient: user,
        sender: task.user,
        notifiable: task,
        notification_type: "task_status_changed",
        title: "タスクのステータスが更新されました",
        message: "「#{task.title}」のステータスが「#{old_status}」から「#{task.status}」に変更されました。"
      )
    end
  end

  def self.send_vendor_application_submitted_notification(application)
    # お祭りの管理者に通知
    festival_managers = User.joins(:owned_festivals).where(festivals: { id: application.festival_id })

    festival_managers.each do |manager|
      create_notification(
        recipient: manager,
        sender: application.user,
        notifiable: application,
        notification_type: "vendor_application_submitted",
        title: "新しい出店申請が提出されました",
        message: "「#{application.business_name}」から出店申請が提出されました。"
      )
    end
  end

  def self.send_vendor_application_status_notification(application, status)
    title = case status
    when "approved"
              "出店申請が承認されました"
    when "rejected"
              "出店申請が却下されました"
    else
              "出店申請のステータスが更新されました"
    end

    message = case status
    when "approved"
                "「#{application.business_name}」の出店申請が承認されました。おめでとうございます！"
    when "rejected"
                "「#{application.business_name}」の出店申請が却下されました。詳細はお問い合わせください。"
    else
                "「#{application.business_name}」の出店申請ステータスが更新されました。"
    end

    notification_type = status == "approved" ? "vendor_application_approved" : "vendor_application_rejected"

    create_notification(
      recipient: application.user,
      sender: nil, # システム通知または管理者
      notifiable: application,
      notification_type: notification_type,
      title: title,
      message: message
    )
  end

  def self.send_festival_created_notification(festival)
    # お祭りに参加する可能性のあるユーザー（地域住民、ボランティアなど）に通知
    User.where(role: [ "resident", "volunteer" ]).each do |user|
      create_notification(
        recipient: user,
        sender: festival.user,
        notifiable: festival,
        notification_type: "festival_created",
        title: "新しいお祭りが企画されました",
        message: "「#{festival.name}」が企画されました。詳細をご確認ください。"
      )
    end
  end

  def self.send_line_task_created_notification(task)
    return unless task.festival.line_integrations.active_integrations.any?

    task.festival.line_integrations.active_integrations.each do |integration|
      next unless integration.notification_preferences["task_created"]

      message = build_line_task_message(task, "created")
      integration.send_notification(message)
    end
  end

  def self.send_line_task_completed_notification(task)
    return unless task.festival.line_integrations.active_integrations.any?

    task.festival.line_integrations.active_integrations.each do |integration|
      next unless integration.notification_preferences["task_completed"]

      message = build_line_task_message(task, "completed")
      integration.send_notification(message)
    end
  end

  def self.send_line_task_assigned_notification(task, sender)
    return unless task.festival.line_integrations.active_integrations.any?

    task.festival.line_integrations.active_integrations.each do |integration|
      next unless integration.notification_preferences["task_assigned"]

      message = build_line_task_assignment_message(task, sender)
      integration.send_notification(message)
    end
  end

  def self.send_line_deadline_reminder(task)
    return unless task.festival.line_integrations.active_integrations.any?

    task.festival.line_integrations.active_integrations.each do |integration|
      next unless integration.notification_preferences["deadline_reminder"]
      next unless within_notification_hours?(integration)

      message = build_line_deadline_message(task)
      integration.send_notification(message)
    end
  end

  private

  def self.send_line_notification(notification)
    return unless notification.recipient.present?

    # Find LINE integrations for the user's festivals
    line_integrations = LineIntegration.joins(:festival)
                                      .where(festivals: { user: notification.recipient })
                                      .active_integrations

    line_integrations.each do |integration|
      next unless should_send_line_notification?(integration, notification)

      message = build_line_notification_message(notification)
      integration.send_notification(message)
    end
  end

  def self.should_send_line_notification?(integration, notification)
    prefs = integration.notification_preferences
    return false unless prefs[notification.notification_type]
    return false unless within_notification_hours?(integration)

    # Check if mention-only mode is enabled
    if prefs["mention_only"] && notification.notifiable.respond_to?(:mentioned_users)
      return notification.notifiable.mentioned_users.include?(notification.recipient)
    end

    true
  end

  def self.within_notification_hours?(integration)
    return true unless integration.notification_preferences["quiet_hours_enabled"]

    times = integration.notification_preferences["notification_times"]
    return true unless times["start"] && times["end"]

    current_time = Time.current.strftime("%H:%M")
    start_time = times["start"]
    end_time = times["end"]

    if start_time < end_time
      current_time >= start_time && current_time <= end_time
    else
      # Handle overnight period (e.g., 22:00 to 07:00)
      current_time >= start_time || current_time <= end_time
    end
  end

  def self.build_line_notification_message(notification)
    case notification.notification_type
    when "task_deadline_reminder"
      "⏰ #{notification.title}\n#{notification.message}"
    when "task_assigned"
      "📝 #{notification.title}\n#{notification.message}"
    when "task_completed"
      "✅ #{notification.title}\n#{notification.message}"
    when "festival_created"
      "🎭 #{notification.title}\n#{notification.message}"
    else
      "📢 #{notification.title}\n#{notification.message}"
    end
  end

  def self.build_line_task_message(task, action)
    case action
    when "created"
      "📝 新しいタスクが作成されました\n" \
      "タイトル: #{task.title}\n" \
      "担当者: #{task.user&.display_name || '未設定'}\n" \
      "期限: #{task.due_date&.strftime('%Y年%m月%d日') || '未設定'}\n" \
      "優先度: #{task.priority_label}"
    when "completed"
      "✅ タスクが完了しました\n" \
      "タイトル: #{task.title}\n" \
      "完了者: #{task.user&.display_name}"
    end
  end

  def self.build_line_task_assignment_message(task, sender)
    "👤 タスクが割り当てられました\n" \
    "タイトル: #{task.title}\n" \
    "担当者: #{task.user&.display_name}\n" \
    "割り当て者: #{sender&.display_name || 'システム'}\n" \
    "期限: #{task.due_date&.strftime('%Y年%m月%d日') || '未設定'}"
  end

  def self.build_line_deadline_message(task)
    days_until = (task.due_date - Date.current).to_i

    if days_until == 0
      urgency = "⚠️ 今日が期限です！"
    elsif days_until == 1
      urgency = "📅 明日が期限です"
    elsif days_until < 0
      urgency = "🚨 期限を#{-days_until}日過ぎています"
    else
      urgency = "📅 あと#{days_until}日で期限です"
    end

    "#{urgency}\n" \
    "タスク: #{task.title}\n" \
    "担当者: #{task.user&.display_name}\n" \
    "期限: #{task.due_date.strftime('%Y年%m月%d日')}"
  end

  def self.broadcast_notification(notification)
    # ActionCableでリアルタイム通知を送信
    ActionCable.server.broadcast(
      "notifications_#{notification.recipient_id}",
      {
        id: notification.id,
        title: notification.title,
        message: notification.message,
        notification_type: notification.notification_type,
        created_at: notification.created_at.iso8601,
        notifiable_type: notification.notifiable_type,
        notifiable_id: notification.notifiable_id
      }
    )
  end
end
