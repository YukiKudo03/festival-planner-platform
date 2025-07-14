class FestivalSerializer
  attr_reader :festival, :options

  def initialize(festival, options = {})
    @festival = festival
    @options = options
  end

  def as_json
    base_attributes.tap do |json|
      json.merge!(detailed_attributes) if options[:detailed]
      json.merge!(task_data) if options[:include_tasks]
      json.merge!(vendor_data) if options[:include_vendors]
      json.merge!(budget_data) if options[:include_budget]
      json.merge!(venue_data) if options[:include_venue]
      json.merge!(member_data) if options[:include_members]
    end
  end

  private

  def base_attributes
    {
      id: festival.id,
      name: festival.name,
      description: festival.description,
      start_date: festival.start_date,
      end_date: festival.end_date,
      location: festival.location,
      status: festival.status,
      public: festival.public?,
      featured: festival.featured?,
      capacity: festival.capacity,
      ticket_price: festival.ticket_price,
      website_url: festival.website_url,
      contact_email: festival.contact_email,
      contact_phone: festival.contact_phone,
      tags: festival.tags,
      created_at: festival.created_at,
      updated_at: festival.updated_at,
      urls: {
        self: api_v1_festival_url(festival),
        dashboard: api_v1_festival_dashboard_url(festival),
        analytics: api_v1_festival_analytics_url(festival)
      }
    }
  end

  def detailed_attributes
    {
      budget: festival.budget,
      budget_utilization: festival.budget_utilization_percentage,
      completion_rate: festival.task_completion_percentage,
      vendor_count: festival.vendor_applications.count,
      approved_vendor_count: festival.vendor_applications.approved.count,
      task_count: festival.tasks.count,
      completed_task_count: festival.tasks.completed.count,
      member_count: festival.festival_members.count,
      created_by: {
        id: festival.created_by&.id,
        name: festival.created_by&.name,
        email: festival.created_by&.email
      },
      stats: {
        total_revenue: festival.revenues.confirmed.sum(:amount),
        total_expenses: festival.expenses.approved.sum(:amount),
        net_profit: festival.revenues.confirmed.sum(:amount) - festival.expenses.approved.sum(:amount),
        vendor_approval_rate: festival.vendor_approval_rate,
        task_completion_rate: festival.task_completion_percentage,
        days_until_start: festival.days_until_start,
        is_active: festival.active?
      }
    }
  end

  def task_data
    return { tasks: [] } unless festival.tasks.any?

    {
      tasks: festival.tasks.limit(10).map do |task|
        {
          id: task.id,
          title: task.title,
          description: task.description,
          status: task.status,
          priority: task.priority,
          due_date: task.due_date,
          assigned_to: task.assigned_to&.name,
          completed_at: task.completed_at,
          created_at: task.created_at
        }
      end,
      task_summary: {
        total: festival.tasks.count,
        pending: festival.tasks.pending.count,
        in_progress: festival.tasks.in_progress.count,
        completed: festival.tasks.completed.count,
        overdue: festival.tasks.overdue.count
      }
    }
  end

  def vendor_data
    return { vendors: [] } unless festival.vendor_applications.any?

    {
      vendors: festival.vendor_applications.limit(10).includes(:user).map do |application|
        {
          id: application.id,
          vendor_name: application.vendor_name,
          contact_person: application.contact_person,
          status: application.status,
          application_type: application.application_type,
          booth_size: application.booth_size,
          products_services: application.products_services,
          submitted_at: application.created_at,
          reviewed_at: application.reviewed_at,
          user: {
            id: application.user.id,
            name: application.user.name,
            email: application.user.email
          }
        }
      end,
      vendor_summary: {
        total_applications: festival.vendor_applications.count,
        pending: festival.vendor_applications.pending.count,
        under_review: festival.vendor_applications.under_review.count,
        approved: festival.vendor_applications.approved.count,
        rejected: festival.vendor_applications.rejected.count,
        approval_rate: festival.vendor_approval_rate
      }
    }
  end

  def budget_data
    return { budget: {} } unless festival.budget_categories.any?

    {
      budget: {
        total_budget: festival.budget,
        total_expenses: festival.expenses.approved.sum(:amount),
        total_revenues: festival.revenues.confirmed.sum(:amount),
        utilization_rate: festival.budget_utilization_percentage,
        categories: festival.budget_categories.map do |category|
          {
            id: category.id,
            name: category.name,
            budget_limit: category.budget_limit,
            spent_amount: category.total_expenses,
            remaining_amount: category.remaining_budget,
            utilization_rate: category.budget_usage_percentage
          }
        end,
        recent_expenses: festival.expenses.recent.limit(5).map do |expense|
          {
            id: expense.id,
            description: expense.description,
            amount: expense.amount,
            category: expense.budget_category&.name,
            status: expense.status,
            expense_date: expense.expense_date
          }
        end
      }
    }
  end

  def venue_data
    return { venue: nil } unless festival.venue

    {
      venue: {
        id: festival.venue.id,
        name: festival.venue.name,
        address: festival.venue.address,
        capacity: festival.venue.capacity,
        layout_elements_count: festival.venue.layout_elements.count,
        booth_count: festival.venue.booths.count,
        assigned_booths: festival.venue.booths.assigned.count,
        available_booths: festival.venue.booths.available.count
      }
    }
  end

  def member_data
    {
      members: festival.festival_members.includes(:user).limit(10).map do |member|
        {
          id: member.id,
          role: member.role,
          joined_at: member.created_at,
          user: {
            id: member.user.id,
            name: member.user.name,
            email: member.user.email
          }
        }
      end,
      member_summary: {
        total: festival.festival_members.count,
        admins: festival.festival_members.where(role: "admin").count,
        committee_members: festival.festival_members.where(role: "committee_member").count,
        regular_members: festival.festival_members.where(role: "member").count
      }
    }
  end

  def api_v1_festival_url(festival)
    Rails.application.routes.url_helpers.api_v1_festival_url(festival)
  end

  def api_v1_festival_dashboard_url(festival)
    Rails.application.routes.url_helpers.api_v1_festival_dashboard_url(festival)
  end

  def api_v1_festival_analytics_url(festival)
    Rails.application.routes.url_helpers.api_v1_festival_analytics_url(festival)
  end
end
