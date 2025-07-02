# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_07_02_110721) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "application_comments", force: :cascade do |t|
    t.bigint "vendor_application_id", null: false
    t.bigint "user_id", null: false
    t.text "content", null: false
    t.boolean "internal", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["internal"], name: "index_application_comments_on_internal"
    t.index ["user_id", "created_at"], name: "index_application_comments_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_application_comments_on_user_id"
    t.index ["vendor_application_id", "created_at"], name: "idx_on_vendor_application_id_created_at_84101e4b46"
    t.index ["vendor_application_id"], name: "index_application_comments_on_vendor_application_id"
  end

  create_table "application_reviews", force: :cascade do |t|
    t.bigint "vendor_application_id", null: false
    t.bigint "reviewer_id", null: false
    t.integer "action", null: false
    t.text "comment"
    t.text "conditions"
    t.datetime "reviewed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["action"], name: "index_application_reviews_on_action"
    t.index ["reviewer_id", "reviewed_at"], name: "index_application_reviews_on_reviewer_id_and_reviewed_at"
    t.index ["reviewer_id"], name: "index_application_reviews_on_reviewer_id"
    t.index ["vendor_application_id", "created_at"], name: "idx_on_vendor_application_id_created_at_4e2add9370"
    t.index ["vendor_application_id"], name: "index_application_reviews_on_vendor_application_id"
  end

  create_table "festivals", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.datetime "start_date"
    t.datetime "end_date"
    t.string "location"
    t.decimal "budget"
    t.integer "status"
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_festivals_on_user_id"
  end

  create_table "forum_posts", force: :cascade do |t|
    t.bigint "forum_thread_id", null: false
    t.bigint "user_id", null: false
    t.text "content"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["forum_thread_id"], name: "index_forum_posts_on_forum_thread_id"
    t.index ["user_id"], name: "index_forum_posts_on_user_id"
  end

  create_table "forum_threads", force: :cascade do |t|
    t.bigint "forum_id", null: false
    t.bigint "user_id", null: false
    t.string "title"
    t.text "content"
    t.boolean "pinned"
    t.boolean "locked"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["forum_id"], name: "index_forum_threads_on_forum_id"
    t.index ["user_id"], name: "index_forum_threads_on_user_id"
  end

  create_table "forums", force: :cascade do |t|
    t.bigint "festival_id", null: false
    t.string "name"
    t.text "description"
    t.string "category"
    t.boolean "private"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["festival_id"], name: "index_forums_on_festival_id"
  end

  create_table "notification_settings", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "notification_type", null: false
    t.boolean "email_enabled", default: true
    t.boolean "web_enabled", default: true
    t.string "frequency", default: "immediate"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["notification_type"], name: "index_notification_settings_on_notification_type"
    t.index ["user_id", "notification_type"], name: "index_notification_settings_on_user_id_and_notification_type", unique: true
    t.index ["user_id"], name: "index_notification_settings_on_user_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.bigint "recipient_id", null: false
    t.bigint "sender_id"
    t.string "notifiable_type", null: false
    t.bigint "notifiable_id", null: false
    t.string "notification_type", null: false
    t.string "title", null: false
    t.text "message"
    t.datetime "read_at"
    t.datetime "sent_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["notifiable_type", "notifiable_id"], name: "index_notifications_on_notifiable"
    t.index ["notifiable_type", "notifiable_id"], name: "index_notifications_on_notifiable_type_and_notifiable_id"
    t.index ["notification_type"], name: "index_notifications_on_notification_type"
    t.index ["recipient_id", "created_at"], name: "index_notifications_on_recipient_id_and_created_at"
    t.index ["recipient_id", "read_at"], name: "index_notifications_on_recipient_id_and_read_at"
    t.index ["recipient_id"], name: "index_notifications_on_recipient_id"
    t.index ["sender_id"], name: "index_notifications_on_sender_id"
  end

  create_table "reactions", force: :cascade do |t|
    t.string "reactable_type", null: false
    t.bigint "reactable_id", null: false
    t.bigint "user_id", null: false
    t.string "reaction_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["reactable_type", "reactable_id"], name: "index_reactions_on_reactable"
    t.index ["user_id"], name: "index_reactions_on_user_id"
  end

  create_table "tasks", force: :cascade do |t|
    t.string "title"
    t.text "description"
    t.datetime "due_date"
    t.integer "priority"
    t.integer "status"
    t.bigint "user_id", null: false
    t.bigint "festival_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["festival_id"], name: "index_tasks_on_festival_id"
    t.index ["user_id"], name: "index_tasks_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.string "first_name"
    t.string "last_name"
    t.string "phone"
    t.text "bio"
    t.integer "role", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "vendor_applications", force: :cascade do |t|
    t.bigint "festival_id", null: false
    t.bigint "user_id", null: false
    t.string "business_name"
    t.string "business_type"
    t.text "description"
    t.text "requirements"
    t.integer "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "submission_deadline"
    t.datetime "review_deadline"
    t.integer "priority", default: 1
    t.text "notes"
    t.datetime "submitted_at"
    t.datetime "reviewed_at"
    t.index ["festival_id"], name: "index_vendor_applications_on_festival_id"
    t.index ["priority"], name: "index_vendor_applications_on_priority"
    t.index ["review_deadline"], name: "index_vendor_applications_on_review_deadline"
    t.index ["submission_deadline"], name: "index_vendor_applications_on_submission_deadline"
    t.index ["submitted_at"], name: "index_vendor_applications_on_submitted_at"
    t.index ["user_id"], name: "index_vendor_applications_on_user_id"
  end

  add_foreign_key "application_comments", "users"
  add_foreign_key "application_comments", "vendor_applications"
  add_foreign_key "application_reviews", "users", column: "reviewer_id"
  add_foreign_key "application_reviews", "vendor_applications"
  add_foreign_key "festivals", "users"
  add_foreign_key "forum_posts", "forum_threads"
  add_foreign_key "forum_posts", "users"
  add_foreign_key "forum_threads", "forums"
  add_foreign_key "forum_threads", "users"
  add_foreign_key "forums", "festivals"
  add_foreign_key "notification_settings", "users"
  add_foreign_key "notifications", "users", column: "recipient_id"
  add_foreign_key "notifications", "users", column: "sender_id"
  add_foreign_key "reactions", "users"
  add_foreign_key "tasks", "festivals"
  add_foreign_key "tasks", "users"
  add_foreign_key "vendor_applications", "festivals"
  add_foreign_key "vendor_applications", "users"
end
