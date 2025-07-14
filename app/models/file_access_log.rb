class FileAccessLog < ApplicationRecord
  belongs_to :user
  belongs_to :attachment, class_name: "ActiveStorage::Attachment"

  validates :action, presence: true, inclusion: { in: %w[view download delete upload] }
  validates :ip_address, presence: true
  validates :user_agent, presence: true, length: { maximum: 500 }

  scope :recent, -> { order(created_at: :desc) }
  scope :by_user, ->(user) { where(user: user) }
  scope :by_action, ->(action) { where(action: action) }
  scope :downloads, -> { where(action: "download") }
  scope :uploads, -> { where(action: "upload") }
  scope :views, -> { where(action: "view") }
  scope :deletions, -> { where(action: "delete") }

  def action_text
    case action
    when "view" then "表示"
    when "download" then "ダウンロード"
    when "delete" then "削除"
    when "upload" then "アップロード"
    else action.humanize
    end
  end

  def filename
    attachment&.blob&.filename&.to_s || "不明なファイル"
  end

  def file_size
    attachment&.blob&.byte_size || 0
  end

  def file_size_formatted
    size = file_size
    return "0 B" if size.zero?

    units = [ "B", "KB", "MB", "GB" ]
    unit_index = 0

    while size >= 1024 && unit_index < units.length - 1
      size /= 1024.0
      unit_index += 1
    end

    "#{size.round(1)} #{units[unit_index]}"
  end

  def content_type
    attachment&.blob&.content_type || "unknown"
  end

  def self.cleanup_old_logs(days_to_keep = 90)
    where("created_at < ?", days_to_keep.days.ago).delete_all
  end

  def self.generate_access_report(date_range = 30.days.ago..Time.current)
    logs_in_range = where(created_at: date_range)

    {
      total_accesses: logs_in_range.count,
      unique_users: logs_in_range.distinct.count(:user_id),
      unique_files: logs_in_range.distinct.count(:attachment_id),
      actions_breakdown: logs_in_range.group(:action).count,
      top_users: top_users_in_period(logs_in_range),
      top_files: top_files_in_period(logs_in_range),
      hourly_distribution: hourly_access_distribution(logs_in_range),
      daily_trend: daily_access_trend(logs_in_range)
    }
  end

  def self.detect_suspicious_activity
    suspicious_activities = []

    # 短時間での大量アクセス
    rapid_access_users = where("created_at >= ?", 1.hour.ago)
                        .group(:user_id)
                        .having("COUNT(*) > ?", 100)
                        .count

    rapid_access_users.each do |user_id, count|
      user = User.find(user_id)
      suspicious_activities << {
        type: "rapid_access",
        user: user,
        details: "1時間で#{count}回のファイルアクセス",
        severity: "high"
      }
    end

    # 異常なIPからのアクセス
    unusual_ips = where("created_at >= ?", 24.hours.ago)
                 .group(:ip_address)
                 .having("COUNT(DISTINCT user_id) > ?", 5)
                 .count

    unusual_ips.each do |ip, count|
      suspicious_activities << {
        type: "unusual_ip",
        ip_address: ip,
        details: "単一IPから#{count}人のユーザーアクセス",
        severity: "medium"
      }
    end

    # 削除アクションの集中
    mass_deletions = where(action: "delete")
                    .where("created_at >= ?", 1.hour.ago)
                    .group(:user_id)
                    .having("COUNT(*) > ?", 10)
                    .count

    mass_deletions.each do |user_id, count|
      user = User.find(user_id)
      suspicious_activities << {
        type: "mass_deletion",
        user: user,
        details: "1時間で#{count}ファイルを削除",
        severity: "high"
      }
    end

    suspicious_activities
  end

  private

  def self.top_users_in_period(logs, limit = 10)
    logs.joins(:user)
        .group("users.id", "users.name", "users.email")
        .order("COUNT(*) DESC")
        .limit(limit)
        .count
        .map do |(user_id, name, email), count|
      {
        user_id: user_id,
        name: name,
        email: email,
        access_count: count
      }
    end
  end

  def self.top_files_in_period(logs, limit = 10)
    logs.joins(attachment: :blob)
        .group("active_storage_attachments.id", "active_storage_blobs.filename")
        .order("COUNT(*) DESC")
        .limit(limit)
        .count
        .map do |(attachment_id, filename), count|
      {
        attachment_id: attachment_id,
        filename: filename,
        access_count: count
      }
    end
  end

  def self.hourly_access_distribution(logs)
    logs.group_by_hour(:created_at, time_zone: "Asia/Tokyo").count
  end

  def self.daily_access_trend(logs)
    logs.group_by_day(:created_at, time_zone: "Asia/Tokyo").count
  end
end
