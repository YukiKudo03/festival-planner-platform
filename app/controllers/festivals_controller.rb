class FestivalsController < ApplicationController
  before_action :set_festival, only: [ :show, :edit, :update, :destroy ]

  def index
    @festivals = Festival.includes(:user, :tasks, :vendor_applications).order(created_at: :desc)
    authorize! :read, Festival

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def show
    authorize! :read, @festival
    @tasks = @festival.tasks.includes(:user)
    @vendor_applications = @festival.vendor_applications.includes(:user)

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def new
    @festival = Festival.new
    authorize! :create, Festival
  end

  def create
    @festival = current_user.owned_festivals.build(festival_params)
    authorize! :create, @festival

    if @festival.save
      redirect_to @festival, notice: "Festival was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize! :update, @festival
  end

  def update
    authorize! :update, @festival

    if @festival.update(festival_params)
      redirect_to @festival, notice: "Festival was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize! :destroy, @festival
    @festival.destroy
    redirect_to festivals_url, notice: "Festival was successfully deleted."
  end

  def gantt
    authorize! :read, @festival
    @tasks = @festival.tasks.includes(:user)

    # ガントチャート用のデータ準備
    @gantt_data = prepare_gantt_data(@tasks)
    @date_range = calculate_date_range(@tasks)

    respond_to do |format|
      format.html
      format.json { render json: @gantt_data }
    end
  end

  private

  def set_festival
    @festival = Festival.find(params[:id])
  end

  def festival_params
    params.require(:festival).permit(:name, :description, :start_date, :end_date, :location, :budget, :status)
  end

  def prepare_gantt_data(tasks)
    tasks.map do |task|
      start_date = task.created_at.to_date
      end_date = task.due_date.to_date
      duration = (end_date - start_date).to_i + 1

      {
        id: task.id,
        name: task.title,
        start: start_date.strftime("%Y-%m-%d"),
        end: end_date.strftime("%Y-%m-%d"),
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
    if tasks.empty?
      return {
        start: @festival.start_date&.to_date || Date.current,
        end: @festival.end_date&.to_date || Date.current + 30.days
      }
    end

    start_dates = tasks.map { |t| t.created_at.to_date }
    end_dates = tasks.map { |t| t.due_date.to_date }

    min_date = start_dates.min
    max_date = end_dates.max

    # お祭りの期間も考慮
    festival_start = @festival.start_date&.to_date
    festival_end = @festival.end_date&.to_date

    if festival_start
      min_date = [ min_date, festival_start ].min
    end

    if festival_end
      max_date = [ max_date, festival_end ].max
    end

    {
      start: min_date - 7.days,
      end: max_date + 7.days
    }
  end

  def task_progress_percentage(task)
    case task.status
    when "pending"
      0
    when "in_progress"
      50
    when "completed"
      100
    when "cancelled"
      0
    else
      0
    end
  end

  def task_gantt_color(task)
    if task.overdue?
      "#dc3545" # 赤色
    elsif task.due_soon?
      "#ffc107" # 黄色
    else
      case task.priority
      when "urgent"
        "#e74c3c"
      when "high"
        "#f39c12"
      when "medium"
        "#3498db"
      when "low"
        "#27ae60"
      else
        "#95a5a6"
      end
    end
  end
end
