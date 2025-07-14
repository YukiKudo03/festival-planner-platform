class ForumThreadsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_festival
  before_action :set_forum
  before_action :set_forum_thread, only: [ :show, :edit, :update, :destroy, :pin, :lock ]
  before_action :check_forum_access, only: [ :show, :new, :create ]
  before_action :check_thread_modification_access, only: [ :edit, :update, :destroy ]
  before_action :check_moderation_access, only: [ :pin, :lock ]

  def show
    @forum_posts = @forum_thread.forum_posts.includes(:user, :reactions, user: :avatar_attachment)
                                              .order(created_at: :asc)
                                              .page(params[:page]).per(20)
    @new_post = @forum_thread.forum_posts.build

    # Mark notifications as read for this thread
    current_user.notifications
                .where(notifiable: @forum_thread)
                .unread
                .update_all(read_at: Time.current)
  end

  def new
    @forum_thread = @forum.forum_threads.build
  end

  def create
    @forum_thread = @forum.forum_threads.build(forum_thread_params)
    @forum_thread.user = current_user

    if @forum_thread.save
      # Create notification for forum participants
      create_thread_notifications

      redirect_to [ @festival, @forum, @forum_thread ],
                  notice: "スレッドが正常に作成されました。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @forum_thread.update(forum_thread_params)
      redirect_to [ @festival, @forum, @forum_thread ],
                  notice: "スレッドが正常に更新されました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @forum_thread.destroy
    redirect_to [ @festival, @forum ],
                notice: "スレッドが正常に削除されました。"
  end

  def pin
    @forum_thread.update(pinned: !@forum_thread.pinned)

    respond_to do |format|
      format.html { redirect_back(fallback_location: [ @festival, @forum, @forum_thread ]) }
      format.json { render json: { pinned: @forum_thread.pinned } }
    end
  end

  def lock
    @forum_thread.update(locked: !@forum_thread.locked)

    respond_to do |format|
      format.html { redirect_back(fallback_location: [ @festival, @forum, @forum_thread ]) }
      format.json { render json: { locked: @forum_thread.locked } }
    end
  end

  private

  def set_festival
    @festival = Festival.find(params[:festival_id])
  end

  def set_forum
    @forum = @festival.forums.find(params[:forum_id])
  end

  def set_forum_thread
    @forum_thread = @forum.forum_threads.find(params[:id])
  end

  def forum_thread_params
    params.require(:forum_thread).permit(:title, :content, :category)
  end

  def check_forum_access
    unless @forum.can_be_accessed_by?(current_user)
      redirect_to @festival, alert: "このフォーラムにアクセスする権限がありません。"
    end
  end

  def check_thread_modification_access
    unless @forum_thread.can_be_modified_by?(current_user)
      redirect_to [ @festival, @forum, @forum_thread ],
                  alert: "このスレッドを編集する権限がありません。"
    end
  end

  def check_moderation_access
    unless current_user.admin? || current_user.committee_member?
      redirect_to [ @festival, @forum, @forum_thread ],
                  alert: "モデレーション権限がありません。"
    end
  end

  def create_thread_notifications
    # Notify forum moderators and interested users
    notification_users = User.joins(:vendor_applications)
                             .where(vendor_applications: { festival: @festival })
                             .where.not(id: current_user.id)
                             .distinct

    notification_users.find_each do |user|
      user.notifications.create!(
        notification_type: "forum_thread_created",
        title: "新しいスレッド: #{@forum_thread.title}",
        message: "#{@forum.name} フォーラムに新しいスレッドが作成されました",
        notifiable: @forum_thread,
        sender: current_user
      )
    end
  end
end
