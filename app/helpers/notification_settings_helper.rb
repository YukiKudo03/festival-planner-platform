module NotificationSettingsHelper
  def notification_type_display_name(type)
    case type
    when 'task_deadline_reminder'
      'タスク期限リマインダー'
    when 'task_overdue'
      'タスク期限切れ通知'
    when 'task_assigned'
      'タスク割り当て通知'
    when 'task_status_changed'
      'タスクステータス変更通知'
    when 'festival_created'
      'お祭り作成通知'
    when 'festival_updated'
      'お祭り更新通知'
    when 'vendor_application_submitted'
      '出店申請提出通知'
    when 'vendor_application_approved'
      '出店申請承認通知'
    when 'vendor_application_rejected'
      '出店申請却下通知'
    when 'system_announcement'
      'システムお知らせ'
    else
      type.humanize
    end
  end

  def notification_type_description(type)
    case type
    when 'task_deadline_reminder'
      'タスクの期限が近づいた時に通知します'
    when 'task_overdue'
      'タスクが期限切れになった時に通知します'
    when 'task_assigned'
      '新しいタスクが割り当てられた時に通知します'
    when 'task_status_changed'
      'タスクのステータスが変更された時に通知します'
    when 'festival_created'
      '新しいお祭りが作成された時に通知します'
    when 'festival_updated'
      'お祭りの情報が更新された時に通知します'
    when 'vendor_application_submitted'
      '出店申請が提出された時に通知します'
    when 'vendor_application_approved'
      '出店申請が承認された時に通知します'
    when 'vendor_application_rejected'
      '出店申請が却下された時に通知します'
    when 'system_announcement'
      'システムからの重要なお知らせを通知します'
    else
      ''
    end
  end

  def frequency_display_name(frequency)
    case frequency
    when 'immediate'
      '即座に'
    when 'daily'
      '1日1回'
    when 'weekly'
      '週1回'
    when 'never'
      '通知しない'
    else
      frequency.humanize
    end
  end

  def frequency_options
    [
      ['即座に', 'immediate'],
      ['1日1回', 'daily'], 
      ['週1回', 'weekly'],
      ['通知しない', 'never']
    ]
  end
end
