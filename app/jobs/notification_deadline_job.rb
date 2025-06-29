class NotificationDeadlineJob < ApplicationJob
  queue_as :default

  def perform
    # 期限が近づいているタスクの通知
    send_deadline_reminders
    
    # 期限切れタスクの通知
    send_overdue_notifications
  end

  private

  def send_deadline_reminders
    # 期限が3日以内のタスクを取得
    due_soon_tasks = Task.due_soon.includes(:user, :festival)
    
    due_soon_tasks.each do |task|
      # 最近同じタスクについて通知を送っていないかチェック
      recent_notification = Notification.where(
        notifiable: task,
        notification_type: 'task_deadline_reminder',
        created_at: 24.hours.ago..Time.current
      ).exists?
      
      next if recent_notification
      
      NotificationService.send_task_deadline_reminder(task)
    end
  end

  def send_overdue_notifications
    # 期限切れのタスクを取得
    overdue_tasks = Task.overdue.includes(:user)
    
    overdue_tasks.each do |task|
      # 最近同じタスクについて通知を送っていないかチェック
      recent_notification = Notification.where(
        notifiable: task,
        notification_type: 'task_overdue',
        created_at: 24.hours.ago..Time.current
      ).exists?
      
      next if recent_notification
      
      NotificationService.send_task_overdue_notification(task)
    end
  end
end
