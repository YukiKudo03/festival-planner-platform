class CreateChatRooms < ActiveRecord::Migration[8.0]
  def change
    create_table :chat_rooms do |t|
      t.string :name
      t.text :description
      t.string :room_type
      t.references :festival, null: false, foreign_key: true
      t.boolean :private

      t.timestamps
    end
  end
end
