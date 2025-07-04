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

  def reaction_emoji(reaction_type)
    case reaction_type
    when 'like'
      '👍'
    when 'love'
      '❤️'
    when 'laugh'
      '😄'
    when 'wow'
      '😮'
    when 'sad'
      '😢'
    when 'angry'
      '😠'
    else
      '👍'
    end
  end
  
  def user_avatar(user, size: 32, css_class: 'rounded-circle')
    if user.avatar.attached?
      image_tag user.avatar, 
                class: css_class, 
                style: "width: #{size}px; height: #{size}px; object-fit: cover;"
    else
      content_tag :div, 
                  user.name.first&.upcase || '?',
                  class: "#{css_class} d-flex align-items-center justify-content-center bg-secondary text-white",
                  style: "width: #{size}px; height: #{size}px; font-size: #{size * 0.4}px; font-weight: bold;"
    end
  end
  
  def badge_for_user_role(user)
    return unless user
    
    if user.admin?
      content_tag :span, 'Admin', class: 'badge bg-danger ms-1'
    elsif user.committee_member?
      content_tag :span, 'Committee', class: 'badge bg-warning ms-1'
    elsif user.vendor?
      content_tag :span, 'Vendor', class: 'badge bg-success ms-1'
    end
  end
  
  def markdown_to_html(text)
    return '' if text.blank?
    
    # Simple markdown-like formatting
    formatted = text.dup
    
    # Bold **text**
    formatted.gsub!(/\*\*(.*?)\*\*/, '<strong>\1</strong>')
    
    # Italic *text*
    formatted.gsub!(/\*(.*?)\*/, '<em>\1</em>')
    
    # Line breaks
    formatted.gsub!(/\n/, '<br>')
    
    # @mentions
    formatted.gsub!(/@(\w+)/, '<span class="text-primary">@\1</span>')
    
    # URLs
    formatted.gsub!(/(https?:\/\/[^\s]+)/, '<a href="\1" target="_blank" rel="noopener">\1</a>')
    
    formatted.html_safe
  end
end
