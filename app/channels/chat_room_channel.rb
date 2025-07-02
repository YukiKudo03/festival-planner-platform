class ChatRoomChannel < ApplicationCable::Channel
  def subscribed
    room = ChatRoom.find(params[:room_id])
    
    # ユーザーがルームにアクセス可能かチェック
    if room.can_be_accessed_by?(current_user)
      stream_for room
      
      # ユーザーをルームメンバーに追加（存在しない場合）
      room.add_member(current_user) unless room.members.include?(current_user)
      
      # オンライン状態を更新
      update_user_presence(room, 'online')
      
      # 他のユーザーにオンライン状態を通知
      broadcast_presence_update(room, current_user, 'online')
    else
      reject
    end
  end

  def unsubscribed
    room = ChatRoom.find(params[:room_id])
    update_user_presence(room, 'offline')
    broadcast_presence_update(room, current_user, 'offline')
  end

  def speak(data)
    room = ChatRoom.find(params[:room_id])
    
    return unless room.can_send_messages?(current_user)
    
    message = room.chat_messages.build(
      user: current_user,
      content: data['content'],
      message_type: data['message_type'] || 'text'
    )
    
    if message.save
      # ブロードキャストはafter_createコールバックで自動実行される
      mark_room_as_read(room)
    else
      # エラーメッセージを送信者にのみ送信
      transmit({
        type: 'error',
        message: message.errors.full_messages.join(', ')
      })
    end
  end

  def mark_as_read
    room = ChatRoom.find(params[:room_id])
    mark_room_as_read(room)
  end

  def typing(data)
    room = ChatRoom.find(params[:room_id])
    
    # 自分以外のルームメンバーにタイピング状態を通知
    ChatRoomChannel.broadcast_to(
      room,
      {
        type: 'typing',
        user: {
          id: current_user.id,
          name: current_user.display_name
        },
        is_typing: data['is_typing']
      }
    )
  end

  def react_to_message(data)
    room = ChatRoom.find(params[:room_id])
    message = room.chat_messages.find(data['message_id'])
    
    # 既存のリアクションを削除または更新
    existing_reaction = message.reactions.find_by(user: current_user)
    
    if existing_reaction
      if existing_reaction.reaction_type == data['reaction_type']
        # 同じリアクションの場合は削除
        existing_reaction.destroy
        reaction_type = nil
      else
        # 違うリアクションの場合は更新
        existing_reaction.update(reaction_type: data['reaction_type'])
        reaction_type = data['reaction_type']
      end
    else
      # 新しいリアクションを作成
      message.reactions.create(
        user: current_user,
        reaction_type: data['reaction_type']
      )
      reaction_type = data['reaction_type']
    end
    
    # リアクション更新を他のユーザーに通知
    ChatRoomChannel.broadcast_to(
      room,
      {
        type: 'reaction_update',
        message_id: message.id,
        user_id: current_user.id,
        reaction_type: reaction_type,
        reaction_summary: message.reload.reaction_summary
      }
    )
  end

  private

  def current_user
    env['warden'].user
  end

  def update_user_presence(room, status)
    member = room.chat_room_members.find_by(user: current_user)
    member&.update(last_read_at: Time.current) if status == 'online'
  end

  def mark_room_as_read(room)
    member = room.chat_room_members.find_by(user: current_user)
    member&.mark_as_read!
  end

  def broadcast_presence_update(room, user, status)
    ChatRoomChannel.broadcast_to(
      room,
      {
        type: 'presence_update',
        user: {
          id: user.id,
          name: user.display_name,
          status: status
        }
      }
    )
  end
end
