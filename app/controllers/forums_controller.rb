class ForumsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_festival, only: [:index, :new, :create]
  before_action :set_forum, only: [:show, :edit, :update, :destroy]
  before_action :check_access_permission, only: [:show]
  before_action :check_modify_permission, only: [:edit, :update, :destroy]

  def index
    @forums = @festival.forums.includes(:forum_threads)
    @forums = @forums.public_forums unless can_access_private_forums?
    @forums = @forums.by_category(params[:category]) if params[:category].present?
    
    @categories = Forum::CATEGORIES
    @total_threads = @forums.sum(&:thread_count)
    @total_posts = @forums.sum(&:post_count)
  end

  def show
    @threads = @forum.forum_threads.includes(:user, :latest_post, :reactions)
                    .order(:pinned => :desc, :updated_at => :desc)
                    .limit(50)
    
    @new_thread = ForumThread.new if can_create_thread?
    @recent_activity = @forum.latest_activity
  end

  def new
    @forum = @festival.forums.build
    authorize_forum_creation!
  end

  def create
    @forum = @festival.forums.build(forum_params)
    authorize_forum_creation!
    
    if @forum.save
      redirect_to festival_forum_path(@festival, @forum), notice: 'フォーラムを作成しました。'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @forum.update(forum_params)
      redirect_to festival_forum_path(@forum.festival, @forum), notice: 'フォーラムを更新しました。'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    festival = @forum.festival
    @forum.destroy
    redirect_to festival_forums_path(festival), notice: 'フォーラムを削除しました。'
  end

  private

  def set_festival
    @festival = Festival.find(params[:festival_id])
  end

  def set_forum
    @forum = Forum.find(params[:id])
  end

  def forum_params
    params.require(:forum).permit(:name, :description, :category, :private)
  end

  def can_access_private_forums?
    current_user.admin? || current_user.committee_member? || 
    current_user.festivals.include?(@festival)
  end

  def can_create_thread?
    @forum.can_be_accessed_by?(current_user)
  end

  def check_access_permission
    unless @forum.can_be_accessed_by?(current_user)
      redirect_to root_path, alert: 'このフォーラムにアクセスする権限がありません。'
    end
  end

  def check_modify_permission
    unless current_user.admin? || current_user.committee_member?
      redirect_to forum_path(@forum), alert: 'フォーラムを編集する権限がありません。'
    end
  end

  def authorize_forum_creation!
    unless current_user.admin? || current_user.committee_member? || 
           current_user.festivals.include?(@festival)
      redirect_to root_path, alert: 'フォーラムを作成する権限がありません。'
    end
  end
end
