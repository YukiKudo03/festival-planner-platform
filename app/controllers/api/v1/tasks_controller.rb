class Api::V1::TasksController < Api::V1::BaseController
  before_action :set_festival, only: [:index, :create]
  before_action :set_task, only: [:show, :update, :destroy, :assign, :complete]
  before_action :authorize_festival_access, only: [:index, :create]
  before_action :authorize_task_access, only: [:show, :update, :destroy, :assign, :complete]

  # GET /api/v1/festivals/:festival_id/tasks
  # GET /api/v1/tasks
  def index
    @tasks = if @festival
               @festival.tasks.includes(:assigned_user, :festival)
             else
               current_user.tasks.includes(:assigned_user, :festival)
             end

    @tasks = filter_tasks(@tasks)
    @tasks = @tasks.page(params[:page]).per(params[:per_page] || 50)

    render json: {
      tasks: @tasks.map { |task| serialize_task(task) },
      meta: pagination_meta(@tasks),
      filters: applied_filters
    }
  end

  # GET /api/v1/tasks/:id
  def show
    render json: {
      task: serialize_task_detailed(@task)
    }
  end

  # POST /api/v1/festivals/:festival_id/tasks
  def create
    @task = @festival.tasks.build(task_params)
    @task.created_by = current_user

    if @task.save
      # LINE integration for task creation
      if @festival.line_integration&.active?
        LineTaskParsingJob.perform_later(@task.id, 'api_created')
      end

      render json: {
        task: serialize_task_detailed(@task),
        message: 'Task created successfully'
      }, status: :created
    else
      render json: {
        errors: @task.errors.full_messages,
        details: @task.errors.details
      }, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /api/v1/tasks/:id
  def update
    if @task.update(task_params)
      render json: {
        task: serialize_task_detailed(@task),
        message: 'Task updated successfully'
      }
    else
      render json: {
        errors: @task.errors.full_messages,
        details: @task.errors.details
      }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/tasks/:id
  def destroy
    @task.destroy
    render json: {
      message: 'Task deleted successfully'
    }
  end

  # POST /api/v1/tasks/:id/assign
  def assign
    assignee = User.find(params[:assignee_id]) if params[:assignee_id]
    
    @task.update(
      assigned_user: assignee,
      assigned_at: assignee ? Time.current : nil
    )

    if @task.save
      # Send notification
      NotificationService.create_notification(
        user: assignee,
        type: 'task_assigned',
        title: 'Task Assigned',
        message: "You have been assigned to task: #{@task.title}",
        related_object: @task
      ) if assignee

      render json: {
        task: serialize_task_detailed(@task),
        message: assignee ? 'Task assigned successfully' : 'Task unassigned successfully'
      }
    else
      render json: {
        errors: @task.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/tasks/:id/complete
  def complete
    @task.update(
      status: 'completed',
      completed_at: Time.current,
      completed_by: current_user
    )

    if @task.save
      # LINE notification for completion
      if @task.festival.line_integration&.active?
        LineNotificationJob.perform_later(
          @task.festival.line_integration.id,
          'task_completed',
          @task.id
        )
      end

      render json: {
        task: serialize_task_detailed(@task),
        message: 'Task completed successfully'
      }
    else
      render json: {
        errors: @task.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  private

  def set_festival
    @festival = Festival.find(params[:festival_id]) if params[:festival_id]
  end

  def set_task
    @task = Task.find(params[:id])
  end

  def authorize_festival_access
    return unless @festival
    
    unless @festival.users.include?(current_user) || current_user.admin?
      render json: { error: 'Access denied to this festival' }, status: :forbidden
    end
  end

  def authorize_task_access
    unless @task.festival.users.include?(current_user) || current_user.admin?
      render json: { error: 'Access denied to this task' }, status: :forbidden
    end
  end

  def task_params
    params.require(:task).permit(
      :title, :description, :priority, :status, :due_date,
      :estimated_hours, :progress, :notes, :category,
      :assigned_user_id, tag_list: []
    )
  end

  def filter_tasks(tasks)
    tasks = tasks.where(status: params[:status]) if params[:status].present?
    tasks = tasks.where(priority: params[:priority]) if params[:priority].present?
    tasks = tasks.where(assigned_user_id: params[:assignee_id]) if params[:assignee_id].present?
    tasks = tasks.where('due_date >= ?', params[:due_from]) if params[:due_from].present?
    tasks = tasks.where('due_date <= ?', params[:due_to]) if params[:due_to].present?
    tasks = tasks.where('title ILIKE ? OR description ILIKE ?', "%#{params[:search]}%", "%#{params[:search]}%") if params[:search].present?
    
    # Sorting
    case params[:sort]
    when 'due_date'
      tasks.order(:due_date)
    when 'priority'
      tasks.order(priority: :desc)
    when 'created'
      tasks.order(created_at: :desc)
    else
      tasks.order(:due_date)
    end
  end

  def applied_filters
    {
      status: params[:status],
      priority: params[:priority],
      assignee_id: params[:assignee_id],
      due_from: params[:due_from],
      due_to: params[:due_to],
      search: params[:search],
      sort: params[:sort]
    }.compact
  end

  def serialize_task(task)
    {
      id: task.id,
      title: task.title,
      description: task.description,
      status: task.status,
      priority: task.priority,
      due_date: task.due_date&.iso8601,
      progress: task.progress,
      category: task.category,
      assigned_user: task.assigned_user ? {
        id: task.assigned_user.id,
        name: task.assigned_user.name,
        email: task.assigned_user.email
      } : nil,
      festival: {
        id: task.festival.id,
        name: task.festival.name
      },
      created_at: task.created_at.iso8601,
      updated_at: task.updated_at.iso8601
    }
  end

  def serialize_task_detailed(task)
    serialize_task(task).merge(
      estimated_hours: task.estimated_hours,
      notes: task.notes,
      tag_list: task.tag_list,
      assigned_at: task.assigned_at&.iso8601,
      completed_at: task.completed_at&.iso8601,
      completed_by: task.completed_by ? {
        id: task.completed_by.id,
        name: task.completed_by.name
      } : nil,
      created_by: task.created_by ? {
        id: task.created_by.id,
        name: task.created_by.name
      } : nil
    )
  end

  def pagination_meta(collection)
    {
      current_page: collection.current_page,
      per_page: collection.limit_value,
      total_pages: collection.total_pages,
      total_count: collection.total_count
    }
  end
end