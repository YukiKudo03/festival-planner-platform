# frozen_string_literal: true

# Tourism Collaboration model for tourism board integration
# Handles tourism promotion, marketing collaboration, and visitor analytics
class TourismCollaboration < ApplicationRecord
  # Associations
  belongs_to :festival
  belongs_to :tourism_board, class_name: 'MunicipalAuthority'
  belongs_to :coordinator, class_name: 'User'
  has_many :tourism_activities, dependent: :destroy
  has_many :marketing_campaigns, dependent: :destroy
  has_many :visitor_analytics, dependent: :destroy
  has_many :tourism_documents, dependent: :destroy

  # Validations
  validates :collaboration_type, presence: true, inclusion: { in: COLLABORATION_TYPES }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :start_date, presence: true
  validates :end_date, presence: true
  validates :budget_allocation, presence: true, numericality: { greater_than: 0 }
  validates :expected_visitors, presence: true, numericality: { greater_than: 0 }

  validate :end_date_after_start_date
  validate :tourism_board_authority_type

  # Enums
  enum collaboration_type: {
    marketing_partnership: 'marketing_partnership',
    promotional_campaign: 'promotional_campaign',
    visitor_experience: 'visitor_experience',
    cultural_exchange: 'cultural_exchange',
    economic_development: 'economic_development',
    destination_branding: 'destination_branding'
  }

  enum status: {
    proposed: 'proposed',
    under_review: 'under_review',
    approved: 'approved',
    active: 'active',
    completed: 'completed',
    cancelled: 'cancelled'
  }

  enum priority: {
    low: 'low',
    medium: 'medium',
    high: 'high',
    strategic: 'strategic'
  }

  # Constants
  COLLABORATION_TYPES = %w[
    marketing_partnership
    promotional_campaign
    visitor_experience
    cultural_exchange
    economic_development
    destination_branding
  ].freeze

  STATUSES = %w[
    proposed
    under_review
    approved
    active
    completed
    cancelled
  ].freeze

  # JSON attributes
  serialize :marketing_objectives, Array
  serialize :target_demographics, Hash
  serialize :promotional_channels, Array
  serialize :collaboration_benefits, Hash
  serialize :performance_metrics, Hash
  serialize :visitor_data, Hash

  # Scopes
  scope :by_collaboration_type, ->(type) { where(collaboration_type: type) }
  scope :by_tourism_board, ->(board) { where(tourism_board: board) }
  scope :active, -> { where(status: 'active') }
  scope :completed, -> { where(status: 'completed') }
  scope :current, -> { where('start_date <= ? AND end_date >= ?', Date.current, Date.current) }
  scope :upcoming, -> { where('start_date > ?', Date.current) }
  scope :by_priority, ->(priority) { where(priority: priority) }

  # Callbacks
  before_create :set_collaboration_number
  after_create :notify_tourism_board
  after_update :track_status_changes, if: :saved_change_to_status?
  after_update :sync_visitor_data, if: :saved_change_to_status?

  # Instance methods

  # Returns human-readable collaboration type
  def collaboration_type_name
    case collaboration_type
    when 'marketing_partnership' then 'マーケティングパートナーシップ'
    when 'promotional_campaign' then 'プロモーションキャンペーン'
    when 'visitor_experience' then '来訪者体験向上'
    when 'cultural_exchange' then '文化交流'
    when 'economic_development' then '経済発展'
    when 'destination_branding' then '目的地ブランディング'
    else collaboration_type.humanize
    end
  end

  # Returns collaboration duration in days
  def duration_days
    (end_date - start_date).to_i
  end

  # Returns days remaining
  def days_remaining
    return 0 if end_date < Date.current
    
    (end_date - Date.current).to_i
  end

  # Returns progress percentage
  def progress_percentage
    return 0 unless start_date && end_date
    return 100 if Date.current >= end_date
    return 0 if Date.current < start_date
    
    total_days = duration_days
    elapsed_days = (Date.current - start_date).to_i
    
    ((elapsed_days.to_f / total_days) * 100).round(1)
  end

  # Activates the collaboration
  def activate!
    return false unless approved?
    
    update!(
      status: 'active',
      activated_at: Time.current
    )
    
    # Initialize tracking metrics
    initialize_performance_tracking
    
    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  # Completes the collaboration
  def complete!(completion_notes: nil)
    return false unless active?
    
    update!(
      status: 'completed',
      completed_at: Time.current,
      completion_notes: completion_notes
    )
    
    # Generate final report
    generate_final_report
    
    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  # Approves the collaboration
  def approve!(approved_by:, notes: nil)
    return false unless %w[proposed under_review].include?(status)
    
    update!(
      status: 'approved',
      approved_at: Time.current,
      approved_by: approved_by,
      approval_notes: notes
    )
    
    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  # Cancels the collaboration
  def cancel!(reason:, cancelled_by:)
    return false if %w[completed cancelled].include?(status)
    
    update!(
      status: 'cancelled',
      cancelled_at: Time.current,
      cancelled_by: cancelled_by,
      cancellation_reason: reason
    )
    
    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  # Returns expected visitor impact
  def visitor_impact_estimate
    base_estimate = expected_visitors
    
    # Apply multipliers based on collaboration type
    multiplier = case collaboration_type
                when 'destination_branding' then 1.5
                when 'marketing_partnership' then 1.3
                when 'promotional_campaign' then 1.2
                when 'visitor_experience' then 1.1
                else 1.0
                end
    
    (base_estimate * multiplier).round(0)
  end

  # Returns economic impact estimate
  def economic_impact_estimate
    visitor_impact = visitor_impact_estimate
    avg_spending_per_visitor = 8000 # Average spending in yen
    
    visitor_impact * avg_spending_per_visitor
  end

  # Returns collaboration ROI
  def return_on_investment
    return 0 if budget_allocation.zero?
    
    economic_impact = economic_impact_estimate
    roi = ((economic_impact - budget_allocation).to_f / budget_allocation * 100).round(2)
    
    [roi, 0].max # Ensure non-negative ROI
  end

  # Updates visitor analytics
  def update_visitor_analytics(analytics_data)
    self.visitor_data = (visitor_data || {}).merge(analytics_data)
    
    # Update performance metrics
    update_performance_metrics(analytics_data)
    
    save!
  end

  # Returns target demographic summary
  def target_demographic_summary
    demographics = target_demographics || {}
    
    {
      age_groups: demographics['age_groups'] || [],
      interests: demographics['interests'] || [],
      geographic_origin: demographics['geographic_origin'] || [],
      spending_capacity: demographics['spending_capacity'] || 'medium',
      visit_purpose: demographics['visit_purpose'] || []
    }
  end

  # Returns marketing channel effectiveness
  def marketing_channel_effectiveness
    channels = promotional_channels || []
    visitor_sources = visitor_data['visitor_sources'] || {}
    
    effectiveness = {}
    channels.each do |channel|
      visitors_from_channel = visitor_sources[channel] || 0
      effectiveness[channel] = {
        visitors_acquired: visitors_from_channel,
        cost_per_acquisition: calculate_cost_per_acquisition(channel, visitors_from_channel),
        effectiveness_score: calculate_effectiveness_score(channel, visitors_from_channel)
      }
    end
    
    effectiveness
  end

  # Returns collaboration summary
  def summary
    {
      collaboration_number: collaboration_number,
      collaboration_type: collaboration_type_name,
      status: status.humanize,
      festival_name: festival.name,
      tourism_board: tourism_board.name,
      duration: "#{start_date} - #{end_date}",
      budget_allocation: "¥#{budget_allocation.to_s(:delimited)}",
      expected_visitors: expected_visitors,
      progress_percentage: progress_percentage,
      economic_impact: "¥#{economic_impact_estimate.to_s(:delimited)}",
      roi: "#{return_on_investment}%"
    }
  end

  # Class methods
  class << self
    # Returns collaborations requiring attention
    def requiring_attention
      where(status: ['proposed', 'under_review']).or(
        where(status: 'active').where('end_date < ?', 7.days.from_now)
      )
    end

    # Returns collaboration statistics
    def collaboration_statistics(period: 1.year)
      collaborations = where(created_at: period.ago..Time.current)
      
      {
        total_collaborations: collaborations.count,
        active_collaborations: collaborations.active.count,
        completed_collaborations: collaborations.completed.count,
        total_budget_allocated: collaborations.sum(:budget_allocation),
        total_expected_visitors: collaborations.sum(:expected_visitors),
        average_roi: collaborations.completed.average('return_on_investment'),
        by_type: collaborations.group(:collaboration_type).count,
        by_status: collaborations.group(:status).count
      }
    end

    # Returns top performing collaborations
    def top_performers(limit: 10)
      completed.order(return_on_investment: :desc).limit(limit)
    end

    # Finds collaborations for festival
    def for_festival(festival)
      where(festival: festival)
    end

    # Returns collaborations by tourism board
    def by_tourism_board(board)
      where(tourism_board: board)
    end

    # Import collaboration opportunities from tourism data
    def import_opportunities(tourism_data)
      opportunities_created = 0
      
      tourism_data.each do |data|
        next unless data[:festival_id] && data[:tourism_board_id]
        
        collaboration = find_or_initialize_by(
          festival_id: data[:festival_id],
          tourism_board_id: data[:tourism_board_id],
          collaboration_type: data[:collaboration_type]
        )
        
        if collaboration.new_record?
          collaboration.assign_attributes(
            coordinator_id: data[:coordinator_id],
            start_date: data[:start_date],
            end_date: data[:end_date],
            budget_allocation: data[:budget_allocation],
            expected_visitors: data[:expected_visitors],
            marketing_objectives: data[:marketing_objectives],
            target_demographics: data[:target_demographics],
            status: 'proposed'
          )
          
          if collaboration.save
            opportunities_created += 1
          end
        end
      end
      
      opportunities_created
    end
  end

  private

  def end_date_after_start_date
    return unless start_date && end_date
    
    if end_date < start_date
      errors.add(:end_date, 'must be after start date')
    end
  end

  def tourism_board_authority_type
    return unless tourism_board
    
    unless tourism_board.authority_type == 'tourism_board'
      errors.add(:tourism_board, 'must be a tourism board authority')
    end
  end

  def set_collaboration_number
    year = Date.current.year
    sequence = TourismCollaboration.where('created_at >= ?', Date.current.beginning_of_year).count + 1
    board_code = tourism_board.code || tourism_board.id.to_s.rjust(3, '0')
    type_code = collaboration_type.first(2).upcase
    
    self.collaboration_number = "TC#{year}#{board_code}#{type_code}#{sequence.to_s.rjust(4, '0')}"
  end

  def notify_tourism_board
    TourismCollaborationMailer.collaboration_proposed(self).deliver_later
  end

  def track_status_changes
    Rails.logger.info "Tourism collaboration #{id} status changed from #{status_before_last_save} to #{status}"
  end

  def sync_visitor_data
    return unless active? || completed?
    
    # Sync with tourism board analytics if API is available
    if tourism_board.api_integration_available?
      TourismAnalyticsSyncJob.perform_later(self)
    end
  end

  def initialize_performance_tracking
    self.performance_metrics = {
      start_date: Date.current,
      baseline_visitors: 0,
      target_metrics: {
        visitor_increase: (expected_visitors * 0.1).round(0),
        engagement_rate: 0.15,
        conversion_rate: 0.08
      }
    }
    save!
  end

  def update_performance_metrics(analytics_data)
    metrics = performance_metrics || {}
    
    metrics.merge!({
      current_visitors: analytics_data['total_visitors'],
      visitor_growth: calculate_visitor_growth(analytics_data),
      channel_performance: analytics_data['channel_data'],
      last_updated: Time.current
    })
    
    self.performance_metrics = metrics
  end

  def calculate_visitor_growth(analytics_data)
    baseline = performance_metrics&.dig('baseline_visitors') || 0
    current = analytics_data['total_visitors'] || 0
    
    return 0 if baseline.zero?
    
    ((current - baseline).to_f / baseline * 100).round(2)
  end

  def calculate_cost_per_acquisition(channel, visitors)
    return 0 if visitors.zero?
    
    channel_budget = budget_allocation / (promotional_channels&.length || 1)
    (channel_budget.to_f / visitors).round(0)
  end

  def calculate_effectiveness_score(channel, visitors)
    # Score based on visitors acquired vs expected
    expected_per_channel = expected_visitors / (promotional_channels&.length || 1)
    
    return 0 if expected_per_channel.zero?
    
    score = (visitors.to_f / expected_per_channel * 100).round(1)
    [score, 200].min # Cap at 200% effectiveness
  end

  def generate_final_report
    TourismReportGeneratorJob.perform_later(self)
  end
end