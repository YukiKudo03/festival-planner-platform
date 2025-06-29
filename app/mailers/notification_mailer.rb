class NotificationMailer < ApplicationMailer
  default from: 'noreply@festival-planner.com'

  def send_notification(notification)
    @notification = notification
    @recipient = notification.recipient
    @sender = notification.sender
    @notifiable = notification.notifiable

    mail(
      to: @recipient.email,
      subject: @notification.title
    )
  end

  def task_deadline_reminder(notification)
    @notification = notification
    @recipient = notification.recipient
    @task = notification.notifiable

    mail(
      to: @recipient.email,
      subject: "【タスク期限通知】#{@task.title}"
    )
  end

  def task_overdue(notification)
    @notification = notification
    @recipient = notification.recipient
    @task = notification.notifiable

    mail(
      to: @recipient.email,
      subject: "【期限切れ】#{@task.title}"
    )
  end

  def task_assigned(notification)
    @notification = notification
    @recipient = notification.recipient
    @sender = notification.sender
    @task = notification.notifiable

    mail(
      to: @recipient.email,
      subject: "【新しいタスク】#{@task.title}"
    )
  end

  def vendor_application_status(notification)
    @notification = notification
    @recipient = notification.recipient
    @application = notification.notifiable

    mail(
      to: @recipient.email,
      subject: "【出店申請】#{@notification.title}"
    )
  end

  def festival_notification(notification)
    @notification = notification
    @recipient = notification.recipient
    @sender = notification.sender
    @festival = notification.notifiable

    mail(
      to: @recipient.email,
      subject: "【お祭り情報】#{@notification.title}"
    )
  end
end
