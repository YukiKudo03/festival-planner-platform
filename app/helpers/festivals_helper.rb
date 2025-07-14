module FestivalsHelper
  def festival_status_text(status)
    case status.to_s
    when "planning"
      "企画中"
    when "preparation"
      "準備中"
    when "active"
      "開催中"
    when "completed"
      "完了"
    when "cancelled"
      "キャンセル"
    else
      status.humanize
    end
  end

  def festival_status_color(status)
    case status.to_s
    when "planning"
      "info"
    when "preparation"
      "warning"
    when "active"
      "success"
    when "completed"
      "primary"
    when "cancelled"
      "danger"
    else
      "secondary"
    end
  end
end
