class BudgetCategory < ApplicationRecord
  belongs_to :festival
  belongs_to :parent, polymorphic: true, optional: true
  
  has_many :expenses, dependent: :destroy
  has_many :revenues, dependent: :destroy
  has_many :budget_approvals, dependent: :destroy
  has_many :child_categories, class_name: 'BudgetCategory', foreign_key: 'parent_id', dependent: :destroy

  validates :name, presence: true, length: { maximum: 100 }
  validates :description, length: { maximum: 500 }, allow_blank: true
  validates :budget_limit, presence: true, numericality: { greater_than_or_equal_to: 0 }

  scope :root_categories, -> { where(parent: nil) }
  scope :by_festival, ->(festival) { where(festival: festival) }

  # 標準的な予算カテゴリ
  STANDARD_CATEGORIES = [
    { name: '会場費', description: '会場使用料、設営費用など' },
    { name: '設備費', description: '音響、照明、その他設備費用' },
    { name: '人件費', description: 'スタッフ、警備、清掃などの人件費' },
    { name: '材料費', description: 'デコレーション、消耗品など' },
    { name: '広告・宣伝費', description: 'ポスター、チラシ、オンライン広告など' },
    { name: '保険・許可費', description: '保険料、許可申請費用など' },
    { name: '飲食費', description: 'スタッフ用飲食、ケータリングなど' },
    { name: '交通費', description: '出演者、スタッフの交通費' },
    { name: '出演料', description: 'アーティスト、パフォーマーへの謝礼' },
    { name: '緊急予備費', description: '予期しない支出への対応費' }
  ].freeze

  def total_expenses
    expenses.sum(:amount) + child_categories.sum(&:total_expenses)
  end

  def total_revenues
    revenues.sum(:amount) + child_categories.sum(&:total_revenues)
  end

  def total_budget_used
    total_expenses
  end

  def budget_remaining
    budget_limit - total_budget_used
  end

  def budget_usage_percentage
    return 0 if budget_limit.zero?
    (total_budget_used / budget_limit * 100).round(2)
  end

  def over_budget?
    total_budget_used > budget_limit
  end

  def near_budget_limit?(threshold = 0.8)
    budget_usage_percentage >= (threshold * 100)
  end

  def hierarchy_path
    path = [name]
    current = parent
    while current.is_a?(BudgetCategory)
      path.unshift(current.name)
      current = current.parent
    end
    path.join(' > ')
  end

  def can_be_modified_by?(user)
    return false unless user
    return true if user.admin? || user.committee_member?
    festival.user == user
  end

  def self.create_standard_categories_for(festival)
    STANDARD_CATEGORIES.each do |category_data|
      festival.budget_categories.find_or_create_by(name: category_data[:name]) do |category|
        category.description = category_data[:description]
        category.budget_limit = 0 # 初期値として0を設定
      end
    end
  end

  def approve_budget!(approver, amount, notes = nil)
    budget_approvals.create!(
      approver: approver,
      requested_amount: amount,
      approved_amount: amount,
      status: 'approved',
      notes: notes
    )
    
    update!(budget_limit: amount)
  end

  def reject_budget!(approver, notes)
    budget_approvals.create!(
      approver: approver,
      requested_amount: budget_limit,
      approved_amount: 0,
      status: 'rejected',
      notes: notes
    )
  end
end
