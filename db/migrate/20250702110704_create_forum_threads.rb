class CreateForumThreads < ActiveRecord::Migration[8.0]
  def change
    create_table :forum_threads do |t|
      t.references :forum, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :title
      t.text :content
      t.boolean :pinned
      t.boolean :locked

      t.timestamps
    end
  end
end
