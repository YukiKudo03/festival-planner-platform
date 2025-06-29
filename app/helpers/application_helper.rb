module ApplicationHelper
  def festival_status_color(status)
    case status
    when 'planning' then 'info'
    when 'preparation' then 'warning'
    when 'active' then 'success'
    when 'completed' then 'secondary'
    when 'cancelled' then 'danger'
    else 'secondary'
    end
  end

  def festival_status_text(status)
    case status
    when 'planning' then '企画中'
    when 'preparation' then '準備中'
    when 'active' then '実施中'
    when 'completed' then '完了'
    when 'cancelled' then '中止'
    else status.humanize
    end
  end

  def task_status_color(status)
    case status
    when 'pending' then 'secondary'
    when 'in_progress' then 'primary'
    when 'completed' then 'success'
    when 'cancelled' then 'danger'
    else 'secondary'
    end
  end

  def task_status_text(status)
    case status
    when 'pending' then '未着手'
    when 'in_progress' then '進行中'
    when 'completed' then '完了'
    when 'cancelled' then 'キャンセル'
    else status.humanize
    end
  end

  def task_priority_color(priority)
    case priority
    when 'low' then 'success'
    when 'medium' then 'warning'
    when 'high' then 'warning'
    when 'urgent' then 'danger'
    else 'secondary'
    end
  end

  def task_priority_text(priority)
    case priority
    when 'low' then '低'
    when 'medium' then '中'
    when 'high' then '高'
    when 'urgent' then '緊急'
    else priority.humanize
    end
  end

  def vendor_status_color(status)
    case status
    when 'pending' then 'warning'
    when 'approved' then 'success'
    when 'rejected' then 'danger'
    when 'cancelled' then 'secondary'
    else 'secondary'
    end
  end

  def vendor_status_text(status)
    case status
    when 'pending' then '審査中'
    when 'approved' then '承認済み'
    when 'rejected' then '却下'
    when 'cancelled' then 'キャンセル'
    else status.humanize
    end
  end
end
