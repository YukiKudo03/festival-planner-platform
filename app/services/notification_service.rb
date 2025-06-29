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
    
    notification
  end

  def self.send_task_deadline_reminder(task)
    task.festival.tasks.joins(:user).includes(:user).each do |festival_task|
      next unless festival_task.user != task.user # 自分以外に通知

      create_notification(
        recipient: festival_task.user,
        sender: nil, # システム通知
        notifiable: task,
        notification_type: 'task_deadline_reminder',
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
      notification_type: 'task_overdue',
      title: "タスクが期限切れになりました",
      message: "「#{task.title}」が期限切れになりました。確認をお願いします。"
    )
  end

  def self.send_task_assigned_notification(task, sender)
    create_notification(
      recipient: task.user,
      sender: sender,
      notifiable: task,
      notification_type: 'task_assigned',
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
        notification_type: 'task_status_changed',
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
        notification_type: 'vendor_application_submitted',
        title: "新しい出店申請が提出されました",
        message: "「#{application.business_name}」から出店申請が提出されました。"
      )
    end
  end

  def self.send_vendor_application_status_notification(application, status)
    title = case status
            when 'approved'
              "出店申請が承認されました"
            when 'rejected'
              "出店申請が却下されました"
            else
              "出店申請のステータスが更新されました"
            end

    message = case status
              when 'approved'
                "「#{application.business_name}」の出店申請が承認されました。おめでとうございます！"
              when 'rejected'
                "「#{application.business_name}」の出店申請が却下されました。詳細はお問い合わせください。"
              else
                "「#{application.business_name}」の出店申請ステータスが更新されました。"
              end

    notification_type = status == 'approved' ? 'vendor_application_approved' : 'vendor_application_rejected'

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
    User.where(role: ['resident', 'volunteer']).each do |user|
      create_notification(
        recipient: user,
        sender: festival.user,
        notifiable: festival,
        notification_type: 'festival_created',
        title: "新しいお祭りが企画されました",
        message: "「#{festival.name}」が企画されました。詳細をご確認ください。"
      )
    end
  end

  private

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