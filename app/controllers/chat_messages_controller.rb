class ChatMessagesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_festival
  before_action :set_chat_room
  before_action :set_chat_message, only: [:edit, :update, :destroy]
  before_action :check_room_access
  before_action :check_message_permissions, only: [:edit, :update, :destroy]

  def create
    @chat_message = @chat_room.chat_messages.build(chat_message_params)
    @chat_message.user = current_user
    
    if @chat_message.save
      # Real-time broadcasting via ActionCable
      broadcast_message(@chat_message)
      
      # Create notifications for room members
      create_message_notifications(@chat_message)
      
      respond_to do |format|
        format.json { 
          render json: { 
            success: true, 
            message: render_message_partial(@chat_message)
          }
        }
        format.html { redirect_to festival_chat_room_path(@festival, @chat_room) }
      end
    else
      respond_to do |format|
        format.json { 
          render json: { 
            success: false, 
            errors: @chat_message.errors.full_messages 
          }, status: :unprocessable_entity
        }
        format.html { 
          @messages = @chat_room.chat_messages.includes(:user, :reactions, attachments: :blob)
                                              .order(created_at: :asc)
                                              .limit(50)
          @new_message = @chat_message
          @members = @chat_room.chat_room_members.includes(:user)
          render 'chat_rooms/show', status: :unprocessable_entity 
        }
      end
    end
  end

  def edit
    respond_to do |format|
      format.json { 
        render json: { 
          success: true, 
          content: @chat_message.content 
        }
      }
      format.html
    end
  end

  def update
    if @chat_message.update(chat_message_params.merge(edited: true))
      # Broadcast the updated message
      broadcast_message_update(@chat_message)
      
      respond_to do |format|
        format.json { 
          render json: { 
            success: true, 
            message: render_message_partial(@chat_message)
          }
        }
        format.html { redirect_to festival_chat_room_path(@festival, @chat_room) }
      end
    else
      respond_to do |format|
        format.json { 
          render json: { 
            success: false, 
            errors: @chat_message.errors.full_messages 
          }, status: :unprocessable_entity
        }
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @chat_message.update(deleted: true, content: "このメッセージは削除されました")
    
    # Broadcast the deletion
    broadcast_message_deletion(@chat_message)
    
    respond_to do |format|
      format.json { render json: { success: true } }
      format.html { redirect_to festival_chat_room_path(@festival, @chat_room) }
    end
  end

  private

  def set_festival
    @festival = Festival.find(params[:festival_id])
  end

  def set_chat_room
    @chat_room = @festival.chat_rooms.find(params[:chat_room_id])
  end

  def set_chat_message
    @chat_message = @chat_room.chat_messages.find(params[:id])
  end

  def chat_message_params
    params.require(:chat_message).permit(:content, :message_type, attachments: [])
  end

  def check_room_access
    unless @chat_room.can_be_accessed_by?(current_user)
      respond_to do |format|
        format.json { render json: { error: 'Access denied' }, status: :forbidden }
        format.html { redirect_to root_path, alert: 'このチャットルームにアクセスする権限がありません。' }
      end
    end
  end

  def check_message_permissions
    unless @chat_message.can_be_modified_by?(current_user)
      respond_to do |format|
        format.json { render json: { error: 'Permission denied' }, status: :forbidden }
        format.html { redirect_to festival_chat_room_path(@festival, @chat_room), alert: 'このメッセージを編集する権限がありません。' }
      end
    end
  end

  def broadcast_message(message)
    ActionCable.server.broadcast(
      "chat_room_#{@chat_room.id}",
      {
        type: 'new_message',
        message: render_message_partial(message),
        message_id: message.id,
        user_id: message.user.id,
        timestamp: message.created_at.iso8601
      }
    )
  end

  def broadcast_message_update(message)
    ActionCable.server.broadcast(
      "chat_room_#{@chat_room.id}",
      {
        type: 'message_updated',
        message: render_message_partial(message),
        message_id: message.id
      }
    )
  end

  def broadcast_message_deletion(message)
    ActionCable.server.broadcast(
      "chat_room_#{@chat_room.id}",
      {
        type: 'message_deleted',
        message_id: message.id,
        message: render_message_partial(message)
      }
    )
  end

  def render_message_partial(message)
    ApplicationController.render(
      partial: 'chat_messages/message',
      locals: { message: message, current_user: current_user }
    )
  end

  def create_message_notifications(message)
    # Get room members excluding the sender
    members = @chat_room.chat_room_members
                        .includes(:user)
                        .where.not(user: current_user)
    
    # Check for mentions in the message
    mentioned_users = extract_mentioned_users(message.content)
    
    members.find_each do |member|
      user = member.user
      
      # Skip if user has disabled chat notifications
      next unless user.notification_settings&.chat_message?
      
      notification_type = if mentioned_users.include?(user)
                           'chat_mention'
                         else
                           'chat_message'
                         end
      
      # Don't create notification if user is currently active in the room
      next if user_active_in_room?(user)
      
      user.notifications.create!(
        notification_type: notification_type,
        title: notification_type == 'chat_mention' ? "#{@chat_room.name} でメンションされました" : "#{@chat_room.name} に新しいメッセージ",
        message: "#{current_user.name}: #{message.content.truncate(50)}",
        notifiable: message,
        sender: current_user
      )
    end
  end

  def extract_mentioned_users(content)
    # Extract @username mentions from content
    usernames = content.scan(/@(\w+)/).flatten
    User.where(name: usernames)
  end

  def user_active_in_room?(user)
    # Check if user has been active in the room within the last 5 minutes
    # This could be tracked via ActionCable presence or a last_seen timestamp
    member = @chat_room.chat_room_members.find_by(user: user)
    return false unless member
    
    # Simple check - if last_read_at is very recent, consider user active
    member.last_read_at && member.last_read_at > 5.minutes.ago
  end
end