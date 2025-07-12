#!/usr/bin/env ruby

puts "新機能のテスト実行..."

# MunicipalAuthorityのテスト
puts "1. MunicipalAuthority作成テスト"
tourism_board = MunicipalAuthority.create!(
  name: "テスト観光局",
  authority_type: "tourism_board",
  contact_person: "田中太郎",
  email: "test@tourism.gov.jp",
  code: "TB001"
)
puts "✅ MunicipalAuthority作成成功: #{tourism_board.name}"

# Userのテスト
puts "2. User作成テスト"
user = User.create!(
  first_name: "太郎",
  last_name: "田中",
  email: "user@test.com",
  password: "password123",
  role: "admin"
)
puts "✅ User作成成功: #{user.full_name}"

# Festivalのテスト
puts "3. Festival作成テスト"
festival = Festival.create!(
  name: "テストフェスティバル",
  start_date: Date.current + 30.days,
  end_date: Date.current + 32.days,
  location: "テスト会場",
  budget: 1000000,
  user: user
)
puts "✅ Festival作成成功: #{festival.name}"

# IndustrySpecializationのテスト
puts "4. IndustrySpecialization作成テスト"
specialization = festival.industry_specializations.create!(
  industry_type: "technology",
  specialization_level: "basic",
  certification_required: false,
  compliance_standards: ["ISO 27001"],
  specialized_features: { "demo_stations" => true }
)
puts "✅ IndustrySpecialization作成成功: #{specialization.industry_name}"

# TourismCollaborationのテスト
puts "5. TourismCollaboration作成テスト"
collaboration = festival.tourism_collaborations.create!(
  collaboration_type: "marketing_partnership",
  tourism_board: tourism_board,
  coordinator: user,
  start_date: Date.current + 10.days,
  end_date: Date.current + 40.days,
  budget_allocation: 500000,
  expected_visitors: 10000,
  marketing_objectives: ["観光客増加"],
  promotional_channels: ["SNS", "Web広告"]
)
puts "✅ TourismCollaboration作成成功: #{collaboration.collaboration_type_name}"

puts "\n🎉 全ての新機能が正常に動作しています！"

# クリーンアップ
puts "\nクリーンアップ中..."
collaboration.destroy!
specialization.destroy!
festival.destroy!
user.destroy!
tourism_board.destroy!
puts "✅ テストデータ削除完了"