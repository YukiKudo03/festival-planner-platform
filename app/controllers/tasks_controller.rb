class TasksController < ApplicationController
  before_action :set_festival, except: [:index]
  before_action :set_task, only: [:show, :edit, :update, :destroy]

  def index
    @tasks = current_user.tasks.includes(:festival, :user)
    authorize! :read, Task
    
    # フィルタリング
    @tasks = filter_tasks(@tasks)
    
    # ソート
    @tasks = sort_tasks(@tasks)
    
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def gantt
    @tasks = current_user.tasks.includes(:festival, :user)
    authorize! :read, Task
    
    # フィルタリング適用
    @tasks = filter_tasks(@tasks)
    
    # ガントチャート用のデータ準備
    @gantt_data = prepare_gantt_data(@tasks)
    @festivals = @tasks.map(&:festival).uniq
    @date_range = calculate_date_range(@tasks)
    
    respond_to do |format|
      format.html
      format.json { render json: @gantt_data }
    end
  end

  def show
    authorize! :read, @task
  end

  def new
    @task = @festival.tasks.build
    authorize! :create, @task
  end

  def create
    @task = @festival.tasks.build(task_params)
    @task.user = current_user
    authorize! :create, @task

    if @task.save
      redirect_to @festival, notice: 'タスクが作成されました。'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize! :update, @task
  end

  def update
    authorize! :update, @task

    if @task.update(task_params)
      redirect_to @festival, notice: 'タスクが更新されました。'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize! :destroy, @task
    @task.destroy
    redirect_to @festival, notice: 'タスクが削除されました。'
  end

  private

  def set_festival
    @festival = Festival.find(params[:festival_id])
  end

  def set_task
    @task = @festival.tasks.find(params[:id])
  end

  def task_params
    params.require(:task).permit(:title, :description, :due_date, :priority, :status, :user_id)
  end

  def filter_tasks(tasks)
    filtered_tasks = tasks
    
    # ステータスフィルタ
    if params[:status].present? && params[:status] != 'all'
      filtered_tasks = filtered_tasks.where(status: params[:status])
    end
    
    # 優先度フィルタ
    if params[:priority].present? && params[:priority] != 'all'
      filtered_tasks = filtered_tasks.where(priority: params[:priority])
    end
    
    # お祭りフィルタ
    if params[:festival_id].present? && params[:festival_id] != 'all'
      filtered_tasks = filtered_tasks.where(festival_id: params[:festival_id])
    end
    
    # 期限フィルタ
    case params[:due_filter]
    when 'overdue'
      filtered_tasks = filtered_tasks.overdue
    when 'due_soon'
      filtered_tasks = filtered_tasks.due_soon
    when 'future'
      filtered_tasks = filtered_tasks.where('due_date > ?', 3.days.from_now)
    end
    
    filtered_tasks
  end
  
  def sort_tasks(tasks)
    case params[:sort]
    when 'due_date_asc'
      tasks.order(due_date: :asc)
    when 'due_date_desc'
      tasks.order(due_date: :desc)
    when 'priority_desc'
      tasks.order(priority: :desc)
    when 'priority_asc'
      tasks.order(priority: :asc)
    when 'created_desc'
      tasks.order(created_at: :desc)
    when 'created_asc'
      tasks.order(created_at: :asc)
    else
      tasks.order(due_date: :asc) # デフォルト
    end
  end

  def prepare_gantt_data(tasks)
    tasks.map do |task|
      start_date = task.created_at.to_date
      end_date = task.due_date.to_date
      duration = (end_date - start_date).to_i + 1
      
      {
        id: task.id,
        name: task.title,
        start: start_date.strftime('%Y-%m-%d'),
        end: end_date.strftime('%Y-%m-%d'),
        duration: duration,
        progress: task_progress_percentage(task),
        priority: task.priority,
        status: task.status,
        festival: task.festival.name,
        festival_id: task.festival.id,
        description: task.description,
        user: task.user.display_name,
        overdue: task.overdue?,
        due_soon: task.due_soon?,
        color: task_gantt_color(task)
      }
    end
  end

  def calculate_date_range(tasks)
    return { start: Date.current, end: Date.current + 30.days } if tasks.empty?
    
    start_dates = tasks.map { |t| t.created_at.to_date }
    end_dates = tasks.map { |t| t.due_date.to_date }
    
    min_date = start_dates.min
    max_date = end_dates.max
    
    # 少し余裕を持たせる
    {
      start: [min_date - 7.days, Date.current - 30.days].max,
      end: [max_date + 7.days, Date.current + 90.days].min
    }
  end

  def task_progress_percentage(task)
    case task.status
    when 'pending'
      0
    when 'in_progress'
      50
    when 'completed'
      100
    when 'cancelled'
      0
    else
      0
    end
  end

  def task_gantt_color(task)
    if task.overdue?
      '#dc3545' # 赤色
    elsif task.due_soon?
      '#ffc107' # 黄色
    else
      case task.priority
      when 'urgent'
        '#e74c3c'
      when 'high'
        '#f39c12'
      when 'medium'
        '#3498db'
      when 'low'
        '#27ae60'
      else
        '#95a5a6'
      end
    end
  end
end
