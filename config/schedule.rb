# Use this file to easily define all of your cron jobs.
# Learn more: http://github.com/javan/whenever

# 毎日朝8時に期限チェック
every 1.day, at: '8:00 am' do
  runner "NotificationDeadlineJob.perform_later"
end

# 毎日夕方6時にも期限チェック（重要なタスク用）
every 1.day, at: '6:00 pm' do
  runner "NotificationDeadlineJob.perform_later"
end

# 古い通知の削除（毎週日曜日の深夜2時）
every :sunday, at: '2:00 am' do
  runner "Notification.cleanup_old_notifications(90)"
end