# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Create sample users with different roles
admin = User.find_or_create_by!(email: 'admin@example.com') do |user|
  user.password = 'password'
  user.password_confirmation = 'password'
  user.first_name = '管理者'
  user.last_name = '太郎'
  user.role = 'admin'
  user.phone = '090-1234-5678'
  user.bio = 'システム管理者です。'
end

committee_member = User.find_or_create_by!(email: 'committee@example.com') do |user|
  user.password = 'password'
  user.password_confirmation = 'password'
  user.first_name = '実行委員'
  user.last_name = '花子'
  user.role = 'committee_member'
  user.phone = '090-2345-6789'
  user.bio = 'お祭り実行委員会のメンバーです。'
end

vendor = User.find_or_create_by!(email: 'vendor@example.com') do |user|
  user.password = 'password'
  user.password_confirmation = 'password'
  user.first_name = '出店者'
  user.last_name = '次郎'
  user.role = 'vendor'
  user.phone = '090-3456-7890'
  user.bio = '地元で飲食店を経営しています。'
end

volunteer = User.find_or_create_by!(email: 'volunteer@example.com') do |user|
  user.password = 'password'
  user.password_confirmation = 'password'
  user.first_name = 'ボランティア'
  user.last_name = '三郎'
  user.role = 'volunteer'
  user.phone = '090-4567-8901'
  user.bio = 'お祭りのボランティアとして参加しています。'
end

resident = User.find_or_create_by!(email: 'resident@example.com') do |user|
  user.password = 'password'
  user.password_confirmation = 'password'
  user.first_name = '地域住民'
  user.last_name = '四郎'
  user.role = 'resident'
  user.phone = '090-5678-9012'
  user.bio = '地域住民として協力しています。'
end

# Create sample festivals
festival1 = Festival.find_or_create_by!(name: '春の桜祭り') do |festival|
  festival.description = '地域の桜の名所で開催される春の祭りです。桜の開花に合わせて、様々なイベントや出店が楽しめます。'
  festival.start_date = 1.month.from_now
  festival.end_date = 1.month.from_now + 2.days
  festival.location = '桜公園'
  festival.budget = 500000
  festival.status = 'preparation'
  festival.user = committee_member
end

festival2 = Festival.find_or_create_by!(name: '夏の盆踊り大会') do |festival|
  festival.description = '伝統的な盆踊りを中心とした夏祭りです。地域の皆様と一緒に踊りましょう。'
  festival.start_date = 3.months.from_now
  festival.end_date = 3.months.from_now + 1.day
  festival.location = '町民会館前広場'
  festival.budget = 300000
  festival.status = 'planning'
  festival.user = committee_member
end

# Create sample tasks
Task.find_or_create_by!(title: '会場設営準備', festival: festival1) do |task|
  task.description = 'テントやステージの設営準備を行います。'
  task.due_date = festival1.start_date - 1.week
  task.priority = 'high'
  task.status = 'pending'
  task.user = volunteer
end

Task.find_or_create_by!(title: '出店者募集', festival: festival1) do |task|
  task.description = '飲食店や物販の出店者を募集します。'
  task.due_date = festival1.start_date - 1.month
  task.priority = 'high'
  task.status = 'in_progress'
  task.user = committee_member
end

Task.find_or_create_by!(title: 'PR用チラシ作成', festival: festival1) do |task|
  task.description = 'お祭りの宣伝用チラシをデザインし印刷します。'
  task.due_date = festival1.start_date - 3.weeks
  task.priority = 'medium'
  task.status = 'completed'
  task.user = resident
end

Task.find_or_create_by!(title: '盆踊り練習会開催', festival: festival2) do |task|
  task.description = '地域住民向けの盆踊り練習会を開催します。'
  task.due_date = festival2.start_date - 2.weeks
  task.priority = 'medium'
  task.status = 'pending'
  task.user = volunteer
end

# Create sample vendor applications
VendorApplication.find_or_create_by!(festival: festival1, user: vendor) do |application|
  application.business_name = 'たこ焼き山田'
  application.business_type = '飲食店'
  application.description = '関西風のたこ焼きを提供いたします。外はカリッと、中はトロトロの絶品たこ焼きです。'
  application.requirements = '電源、水道、テント設営場所が必要です。'
  application.status = 'approved'
end

VendorApplication.find_or_create_by!(festival: festival1, user: resident) do |application|
  application.business_name = '手作りアクセサリー工房'
  application.business_type = '工芸品・手作り品'
  application.description = '地元の素材を使った手作りアクセサリーを販売します。'
  application.requirements = 'テーブルと椅子、テント設営場所をお願いします。'
  application.status = 'pending'
end

puts "シードデータの作成が完了しました。"
puts "作成されたユーザー:"
puts "- 管理者: admin@example.com (password: password)"
puts "- 実行委員: committee@example.com (password: password)"
puts "- 出店者: vendor@example.com (password: password)"
puts "- ボランティア: volunteer@example.com (password: password)"
puts "- 地域住民: resident@example.com (password: password)"
