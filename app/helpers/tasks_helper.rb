module TasksHelper
  def task_status_text(status)
    case status.to_s
    when "pending"
      "未着手"
    when "in_progress"
      "進行中"
    when "completed"
      "完了"
    when "cancelled"
      "キャンセル"
    else
      status.humanize
    end
  end

  def task_status_color(status)
    case status.to_s
    when "pending"
      "secondary"
    when "in_progress"
      "primary"
    when "completed"
      "success"
    when "cancelled"
      "danger"
    else
      "secondary"
    end
  end

  def task_priority_text(priority)
    case priority.to_s
    when "low"
      "低"
    when "medium"
      "中"
    when "high"
      "高"
    when "urgent"
      "緊急"
    else
      priority.humanize
    end
  end

  def task_priority_color(priority)
    case priority.to_s
    when "low"
      "success"
    when "medium"
      "warning"
    when "high"
      "orange"
    when "urgent"
      "danger"
    else
      "secondary"
    end
  end

  def task_card_class(task)
    classes = [ "card", "task-priority-#{task.priority}", "mb-3" ]

    if task.overdue?
      classes << "border-danger"
    elsif task.due_soon?
      classes << "border-warning"
    end

    classes.join(" ")
  end

  def sort_options
    [
      [ "期限日（昇順）", "due_date_asc" ],
      [ "期限日（降順）", "due_date_desc" ],
      [ "優先度（高→低）", "priority_desc" ],
      [ "優先度（低→高）", "priority_asc" ],
      [ "作成日（新→古）", "created_desc" ],
      [ "作成日（古→新）", "created_asc" ]
    ]
  end

  def status_options
    [
      [ "すべて", "all" ],
      [ "未着手", "pending" ],
      [ "進行中", "in_progress" ],
      [ "完了", "completed" ],
      [ "キャンセル", "cancelled" ]
    ]
  end

  def priority_options
    [
      [ "すべて", "all" ],
      [ "緊急", "urgent" ],
      [ "高", "high" ],
      [ "中", "medium" ],
      [ "低", "low" ]
    ]
  end

  def due_filter_options
    [
      [ "すべて", "all" ],
      [ "期限切れ", "overdue" ],
      [ "期限間近（3日以内）", "due_soon" ],
      [ "今後（3日以降）", "future" ]
    ]
  end
end
