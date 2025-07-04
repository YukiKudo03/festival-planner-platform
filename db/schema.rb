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

ActiveRecord::Schema[8.0].define(version: 2025_07_04_121904) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

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

  create_table "booths", force: :cascade do |t|
    t.bigint "venue_area_id", null: false
    t.bigint "festival_id", null: false
    t.bigint "vendor_application_id", null: false
    t.string "name"
    t.string "booth_number"
    t.string "size"
    t.decimal "width"
    t.decimal "height"
    t.decimal "x_position"
    t.decimal "y_position"
    t.decimal "rotation"
    t.string "status"
    t.boolean "power_required"
    t.boolean "water_required"
    t.text "special_requirements"
    t.text "setup_instructions"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["festival_id"], name: "index_booths_on_festival_id"
    t.index ["vendor_application_id"], name: "index_booths_on_vendor_application_id"
    t.index ["venue_area_id"], name: "index_booths_on_venue_area_id"
  end

  create_table "budget_approvals", force: :cascade do |t|
    t.bigint "festival_id", null: false
    t.bigint "budget_category_id", null: false
    t.string "approver_type", null: false
    t.bigint "approver_id", null: false
    t.decimal "requested_amount", precision: 10, scale: 2, null: false
    t.decimal "approved_amount", precision: 10, scale: 2, default: "0.0", null: false
    t.string "status", default: "pending", null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["approver_type", "approver_id"], name: "index_budget_approvals_on_approver"
    t.index ["approver_type", "approver_id"], name: "index_budget_approvals_on_approver_type_and_approver_id"
    t.index ["budget_category_id", "status"], name: "index_budget_approvals_on_budget_category_id_and_status"
    t.index ["budget_category_id"], name: "index_budget_approvals_on_budget_category_id"
    t.index ["festival_id", "status"], name: "index_budget_approvals_on_festival_id_and_status"
    t.index ["festival_id"], name: "index_budget_approvals_on_festival_id"
    t.index ["status"], name: "index_budget_approvals_on_status"
  end

  create_table "budget_categories", force: :cascade do |t|
    t.bigint "festival_id", null: false
    t.string "name"
    t.text "description"
    t.string "parent_type"
    t.bigint "parent_id"
    t.decimal "budget_limit"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["festival_id"], name: "index_budget_categories_on_festival_id"
    t.index ["parent_type", "parent_id"], name: "index_budget_categories_on_parent"
  end

  create_table "chat_messages", force: :cascade do |t|
    t.bigint "chat_room_id", null: false
    t.bigint "user_id", null: false
    t.text "content"
    t.string "message_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["chat_room_id"], name: "index_chat_messages_on_chat_room_id"
    t.index ["user_id"], name: "index_chat_messages_on_user_id"
  end

  create_table "chat_room_members", force: :cascade do |t|
    t.bigint "chat_room_id", null: false
    t.bigint "user_id", null: false
    t.string "role"
    t.datetime "joined_at"
    t.datetime "last_read_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["chat_room_id"], name: "index_chat_room_members_on_chat_room_id"
    t.index ["user_id"], name: "index_chat_room_members_on_user_id"
  end

  create_table "chat_rooms", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.string "room_type"
    t.bigint "festival_id", null: false
    t.boolean "private"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["festival_id"], name: "index_chat_rooms_on_festival_id"
  end

  create_table "expenses", force: :cascade do |t|
    t.bigint "festival_id", null: false
    t.bigint "budget_category_id", null: false
    t.bigint "user_id", null: false
    t.decimal "amount"
    t.text "description"
    t.date "expense_date"
    t.string "payment_method"
    t.string "vendor_name"
    t.string "receipt_number"
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["budget_category_id"], name: "index_expenses_on_budget_category_id"
    t.index ["festival_id"], name: "index_expenses_on_festival_id"
    t.index ["user_id"], name: "index_expenses_on_user_id"
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

  create_table "layout_elements", force: :cascade do |t|
    t.bigint "venue_id", null: false
    t.string "element_type"
    t.string "name"
    t.text "description"
    t.decimal "x_position"
    t.decimal "y_position"
    t.decimal "width"
    t.decimal "height"
    t.decimal "rotation"
    t.string "color"
    t.text "properties"
    t.integer "layer"
    t.boolean "locked"
    t.boolean "visible"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["venue_id"], name: "index_layout_elements_on_venue_id"
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

  create_table "payments", force: :cascade do |t|
    t.bigint "festival_id", null: false
    t.bigint "user_id", null: false
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.string "payment_method", null: false
    t.string "status", default: "pending", null: false
    t.string "currency", default: "JPY"
    t.text "description"
    t.string "customer_email"
    t.string "customer_name"
    t.text "billing_address"
    t.string "external_transaction_id"
    t.decimal "processing_fee", precision: 8, scale: 2, default: "0.0"
    t.json "metadata", default: {}
    t.datetime "processed_at"
    t.datetime "confirmed_at"
    t.datetime "cancelled_at"
    t.text "cancellation_reason"
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["confirmed_at"], name: "index_payments_on_confirmed_at"
    t.index ["external_transaction_id"], name: "index_payments_on_external_transaction_id", unique: true
    t.index ["festival_id", "status"], name: "index_payments_on_festival_id_and_status"
    t.index ["festival_id"], name: "index_payments_on_festival_id"
    t.index ["payment_method"], name: "index_payments_on_payment_method"
    t.index ["processed_at"], name: "index_payments_on_processed_at"
    t.index ["status"], name: "index_payments_on_status"
    t.index ["user_id", "status"], name: "index_payments_on_user_id_and_status"
    t.index ["user_id"], name: "index_payments_on_user_id"
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

  create_table "revenues", force: :cascade do |t|
    t.bigint "festival_id", null: false
    t.bigint "budget_category_id", null: false
    t.bigint "user_id", null: false
    t.decimal "amount"
    t.text "description"
    t.date "revenue_date"
    t.string "source"
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["budget_category_id"], name: "index_revenues_on_budget_category_id"
    t.index ["festival_id"], name: "index_revenues_on_festival_id"
    t.index ["user_id"], name: "index_revenues_on_user_id"
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
    t.string "api_token"
    t.datetime "api_token_expires_at"
    t.datetime "last_api_access_at"
    t.integer "api_request_count", default: 0
    t.json "api_permissions", default: {}
    t.index ["api_token"], name: "index_users_on_api_token", unique: true
    t.index ["api_token_expires_at"], name: "index_users_on_api_token_expires_at"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["last_api_access_at"], name: "index_users_on_last_api_access_at"
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

  create_table "venue_areas", force: :cascade do |t|
    t.bigint "venue_id", null: false
    t.string "name", null: false
    t.text "description"
    t.string "area_type", null: false
    t.decimal "width", precision: 8, scale: 2, null: false
    t.decimal "height", precision: 8, scale: 2, null: false
    t.decimal "x_position", precision: 8, scale: 2, null: false
    t.decimal "y_position", precision: 8, scale: 2, null: false
    t.decimal "rotation", precision: 5, scale: 2, default: "0.0"
    t.string "color"
    t.integer "capacity"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["area_type"], name: "index_venue_areas_on_area_type"
    t.index ["venue_id"], name: "index_venue_areas_on_venue_id"
    t.index ["x_position", "y_position"], name: "index_venue_areas_on_x_position_and_y_position"
  end

  create_table "venues", force: :cascade do |t|
    t.bigint "festival_id", null: false
    t.string "name", null: false
    t.text "description"
    t.integer "capacity", null: false
    t.text "address"
    t.decimal "latitude", precision: 10, scale: 6
    t.decimal "longitude", precision: 10, scale: 6
    t.string "facility_type", null: false
    t.text "contact_info"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["facility_type"], name: "index_venues_on_facility_type"
    t.index ["festival_id"], name: "index_venues_on_festival_id"
    t.index ["latitude", "longitude"], name: "index_venues_on_latitude_and_longitude"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "application_comments", "users"
  add_foreign_key "application_comments", "vendor_applications"
  add_foreign_key "application_reviews", "users", column: "reviewer_id"
  add_foreign_key "application_reviews", "vendor_applications"
  add_foreign_key "booths", "festivals"
  add_foreign_key "booths", "vendor_applications"
  add_foreign_key "booths", "venue_areas"
  add_foreign_key "budget_approvals", "budget_categories"
  add_foreign_key "budget_approvals", "festivals"
  add_foreign_key "budget_categories", "festivals"
  add_foreign_key "chat_messages", "chat_rooms"
  add_foreign_key "chat_messages", "users"
  add_foreign_key "chat_room_members", "chat_rooms"
  add_foreign_key "chat_room_members", "users"
  add_foreign_key "chat_rooms", "festivals"
  add_foreign_key "expenses", "budget_categories"
  add_foreign_key "expenses", "festivals"
  add_foreign_key "expenses", "users"
  add_foreign_key "festivals", "users"
  add_foreign_key "forum_posts", "forum_threads"
  add_foreign_key "forum_posts", "users"
  add_foreign_key "forum_threads", "forums"
  add_foreign_key "forum_threads", "users"
  add_foreign_key "forums", "festivals"
  add_foreign_key "layout_elements", "venues"
  add_foreign_key "notification_settings", "users"
  add_foreign_key "notifications", "users", column: "recipient_id"
  add_foreign_key "notifications", "users", column: "sender_id"
  add_foreign_key "payments", "festivals"
  add_foreign_key "payments", "users"
  add_foreign_key "reactions", "users"
  add_foreign_key "revenues", "budget_categories"
  add_foreign_key "revenues", "festivals"
  add_foreign_key "revenues", "users"
  add_foreign_key "tasks", "festivals"
  add_foreign_key "tasks", "users"
  add_foreign_key "vendor_applications", "festivals"
  add_foreign_key "vendor_applications", "users"
  add_foreign_key "venue_areas", "venues"
  add_foreign_key "venues", "festivals"
end
