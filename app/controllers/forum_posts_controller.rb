class ForumPostsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_festival
  before_action :set_forum
  before_action :set_forum_thread
  before_action :set_forum_post, only: [ :show, :edit, :update, :destroy ]
  before_action :check_forum_access
  before_action :check_thread_locked, only: [ :create, :edit, :update ]
  before_action :check_post_modification_access, only: [ :edit, :update, :destroy ]

  def create
    @forum_post = @forum_thread.forum_posts.build(forum_post_params)
    @forum_post.user = current_user

    if @forum_post.save
      # Update thread's updated_at timestamp
      @forum_thread.touch

      # Create notifications for thread participants
      create_post_notifications

      redirect_to [ @festival, @forum, @forum_thread ],
                  notice: "投稿が正常に作成されました。"
    else
      @forum_posts = @forum_thread.forum_posts.includes(:user, :reactions, user: :avatar_attachment)
                                                .order(created_at: :asc)
                                                .page(params[:page]).per(20)
      @new_post = @forum_post
      render "forum_threads/show", status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @forum_post.update(forum_post_params)
      redirect_to [ @festival, @forum, @forum_thread ],
                  notice: "投稿が正常に更新されました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @forum_post.destroy
    redirect_to [ @festival, @forum, @forum_thread ],
                notice: "投稿が正常に削除されました。"
  end

  private

  def set_festival
    @festival = Festival.find(params[:festival_id])
  end

  def set_forum
    @forum = @festival.forums.find(params[:forum_id])
  end

  def set_forum_thread
    @forum_thread = @forum.forum_threads.find(params[:forum_thread_id])
  end

  def set_forum_post
    @forum_post = @forum_thread.forum_posts.find(params[:id])
  end

  def forum_post_params
    params.require(:forum_post).permit(:content)
  end

  def check_forum_access
    unless @forum.can_be_accessed_by?(current_user)
      redirect_to @festival, alert: "このフォーラムにアクセスする権限がありません。"
    end
  end

  def check_thread_locked
    if @forum_thread.locked?
      redirect_to [ @festival, @forum, @forum_thread ],
                  alert: "このスレッドはロックされているため投稿できません。"
    end
  end

  def check_post_modification_access
    unless @forum_post.can_be_modified_by?(current_user)
      redirect_to [ @festival, @forum, @forum_thread ],
                  alert: "この投稿を編集する権限がありません。"
    end
  end

  def create_post_notifications
    # Get thread participants (excluding the post author)
    participants = @forum_thread.participants.where.not(id: current_user.id)

    participants.find_each do |user|
      # Skip if user has notifications disabled for forum replies
      next unless user.notification_settings&.forum_reply?

      user.notifications.create!(
        notification_type: "forum_reply",
        title: "#{@forum_thread.title} に新しい返信",
        message: "#{current_user.name} が返信しました: #{@forum_post.content.truncate(50)}",
        notifiable: @forum_post,
        sender: current_user
      )
    end

    # Check for mentions in the post content
    mentioned_users = extract_mentioned_users(@forum_post.content)
    mentioned_users.each do |user|
      next if user == current_user # Don't notify the author

      user.notifications.create!(
        notification_type: "forum_mention",
        title: "#{@forum_thread.title} でメンションされました",
        message: "#{current_user.name} があなたをメンションしました",
        notifiable: @forum_post,
        sender: current_user
      )
    end
  end

  def extract_mentioned_users(content)
    # Extract @username mentions from content
    usernames = content.scan(/@(\w+)/).flatten
    User.where(name: usernames)
  end
end
