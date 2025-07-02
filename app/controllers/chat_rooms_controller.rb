class ChatRoomsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_festival, only: [:index, :new, :create]
  before_action :set_chat_room, only: [:show, :edit, :update, :destroy, :join, :leave, :mark_as_read]
  before_action :check_access_permission, only: [:show]
  before_action :check_modify_permission, only: [:edit, :update, :destroy]

  def index
    if params[:festival_id]
      # 特定の祭りのチャットルーム
      @chat_rooms = @festival.chat_rooms.includes(:members, :latest_message)
      @chat_rooms = @chat_rooms.public_rooms unless can_access_private_rooms?
    else
      # 全体のチャットルーム一覧
      @chat_rooms = current_user.chat_rooms.includes(:festival, :members, :latest_message)
                                 .order(updated_at: :desc)
    end
    
    @unread_counts = calculate_unread_counts(@chat_rooms)
  end

  def show
    @messages = @chat_room.chat_messages.includes(:user, :reactions, attachments: :blob)
                          .order(created_at: :asc)
                          .limit(50)
    
    @new_message = ChatMessage.new
    @members = @chat_room.chat_room_members.includes(:user)
    
    # 既読マークを更新
    mark_room_as_read
  end

  def new
    @chat_room = @festival.chat_rooms.build
    authorize_room_creation!
  end

  def create
    @chat_room = @festival.chat_rooms.build(chat_room_params)
    authorize_room_creation!
    
    if @chat_room.save
      # 作成者を管理者として追加
      @chat_room.add_member(current_user, role: 'admin')
      
      redirect_to festival_chat_room_path(@festival, @chat_room), notice: 'チャットルームを作成しました。'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @chat_room.update(chat_room_params)
      redirect_to festival_chat_room_path(@chat_room.festival, @chat_room), notice: 'チャットルームを更新しました。'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    festival = @chat_room.festival
    @chat_room.destroy
    redirect_to festival_chat_rooms_path(festival), notice: 'チャットルームを削除しました。'
  end

  def join
    if @chat_room.add_member(current_user)
      redirect_to festival_chat_room_path(@chat_room.festival, @chat_room), notice: 'チャットルームに参加しました。'
    else
      redirect_back(fallback_location: root_path, alert: 'チャットルームに参加できませんでした。')
    end
  end

  def leave
    if @chat_room.remove_member(current_user)
      redirect_to festival_chat_rooms_path(@chat_room.festival), notice: 'チャットルームから退出しました。'
    else
      redirect_back(fallback_location: root_path, alert: 'チャットルームから退出できませんでした。')
    end
  end

  def mark_as_read
    mark_room_as_read
    head :ok
  end

  def direct_message
    other_user = User.find(params[:user_id])
    
    # 既存のダイレクトメッセージルームを検索
    room = find_or_create_direct_message_room(other_user)
    
    redirect_to chat_room_path(room)
  end

  private

  def set_festival
    @festival = Festival.find(params[:festival_id]) if params[:festival_id]
  end

  def set_chat_room
    @chat_room = ChatRoom.find(params[:id])
  end

  def chat_room_params
    params.require(:chat_room).permit(:name, :description, :room_type, :private)
  end

  def can_access_private_rooms?
    return false unless @festival
    current_user.admin? || current_user.committee_member? || 
    current_user.festivals.include?(@festival)
  end

  def check_access_permission
    unless @chat_room.can_be_accessed_by?(current_user)
      redirect_to root_path, alert: 'このチャットルームにアクセスする権限がありません。'
    end
  end

  def check_modify_permission
    unless current_user.admin? || current_user.committee_member? ||
           @chat_room.member_role(current_user) == 'admin'
      redirect_to chat_room_path(@chat_room), alert: 'チャットルームを編集する権限がありません。'
    end
  end

  def authorize_room_creation!
    unless current_user.admin? || current_user.committee_member? || 
           current_user.festivals.include?(@festival)
      redirect_to root_path, alert: 'チャットルームを作成する権限がありません。'
    end
  end

  def mark_room_as_read
    member = @chat_room.chat_room_members.find_by(user: current_user)
    member&.mark_as_read!
  end

  def calculate_unread_counts(rooms)
    unread_counts = {}
    rooms.each do |room|
      unread_counts[room.id] = room.unread_count_for(current_user)
    end
    unread_counts
  end

  def find_or_create_direct_message_room(other_user)
    # 既存のダイレクトメッセージルームを検索
    existing_room = current_user.chat_rooms
                                .joins(:chat_room_members)
                                .where(room_type: 'direct')
                                .where('chat_room_members.user_id = ?', other_user.id)
                                .first

    return existing_room if existing_room

    # 新しいダイレクトメッセージルームを作成
    festival = current_user.festivals.first || other_user.festivals.first
    return nil unless festival

    room = festival.chat_rooms.create!(
      name: "#{current_user.display_name} & #{other_user.display_name}",
      room_type: 'direct',
      private: true
    )

    room.add_member(current_user)
    room.add_member(other_user)
    
    room
  end
end
