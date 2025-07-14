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

ActiveRecord::Schema[8.0].define(version: 2025_07_14_070200) do
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

  create_table "api_keys", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "name", null: false
    t.string "api_key", null: false
    t.string "key_type", default: "personal", null: false
    t.text "scopes"
    t.text "ip_whitelist"
    t.text "rate_limits"
    t.datetime "expires_at"
    t.boolean "active", default: true
    t.integer "request_count", default: 0
    t.datetime "last_used_at"
    t.datetime "revoked_at"
    t.text "usage_stats"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active", "expires_at"], name: "index_api_keys_on_active_and_expires_at"
    t.index ["api_key"], name: "index_api_keys_on_api_key", unique: true
    t.index ["key_type"], name: "index_api_keys_on_key_type"
    t.index ["last_used_at"], name: "index_api_keys_on_last_used_at"
    t.index ["user_id"], name: "index_api_keys_on_user_id"
  end

  create_table "api_requests", force: :cascade do |t|
    t.bigint "api_key_id", null: false
    t.bigint "user_id"
    t.string "endpoint", null: false
    t.string "method", null: false
    t.string "ip_address", null: false
    t.text "user_agent"
    t.integer "response_status", null: false
    t.float "response_time_ms"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["api_key_id", "created_at"], name: "index_api_requests_on_api_key_id_and_created_at"
    t.index ["api_key_id"], name: "index_api_requests_on_api_key_id"
    t.index ["created_at"], name: "index_api_requests_on_created_at"
    t.index ["endpoint"], name: "index_api_requests_on_endpoint"
    t.index ["ip_address"], name: "index_api_requests_on_ip_address"
    t.index ["method"], name: "index_api_requests_on_method"
    t.index ["response_status", "created_at"], name: "index_api_requests_on_response_status_and_created_at"
    t.index ["response_status"], name: "index_api_requests_on_response_status"
    t.index ["user_id"], name: "index_api_requests_on_user_id"
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
    t.boolean "public", default: false, null: false
    t.index ["user_id"], name: "index_festivals_on_user_id"
  end

  create_table "file_access_logs", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.integer "attachment_id", null: false
    t.string "action", null: false
    t.string "ip_address", null: false
    t.text "user_agent", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["action", "created_at"], name: "index_file_access_logs_on_action_and_created_at"
    t.index ["attachment_id"], name: "index_file_access_logs_on_attachment_id"
    t.index ["created_at"], name: "index_file_access_logs_on_created_at"
    t.index ["user_id", "created_at"], name: "index_file_access_logs_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_file_access_logs_on_user_id"
  end

  create_table "file_metadata", force: :cascade do |t|
    t.bigint "uploaded_by_id", null: false
    t.integer "attachment_id", null: false
    t.string "original_filename", null: false
    t.bigint "file_size", null: false
    t.string "content_type", null: false
    t.string "upload_ip", null: false
    t.text "upload_user_agent", null: false
    t.json "image_metadata"
    t.json "processing_metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["attachment_id"], name: "index_file_metadata_on_attachment_id", unique: true
    t.index ["content_type"], name: "index_file_metadata_on_content_type"
    t.index ["created_at"], name: "index_file_metadata_on_created_at"
    t.index ["file_size"], name: "index_file_metadata_on_file_size"
    t.index ["uploaded_by_id"], name: "index_file_metadata_on_uploaded_by_id"
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

  create_table "industry_specializations", force: :cascade do |t|
    t.bigint "festival_id", null: false
    t.string "industry_type", null: false
    t.string "specialization_level", default: "basic", null: false
    t.string "status", default: "planning", null: false
    t.boolean "certification_required", default: false
    t.text "description"
    t.string "priority", default: "medium"
    t.string "specialization_code"
    t.datetime "activated_at"
    t.datetime "completed_at"
    t.text "completion_notes"
    t.text "compliance_standards"
    t.text "specialized_features"
    t.text "industry_regulations"
    t.text "certification_requirements"
    t.text "performance_kpis"
    t.text "vendor_criteria"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["festival_id", "industry_type"], name: "idx_on_festival_id_industry_type_c6db393dc4", unique: true
    t.index ["festival_id"], name: "index_industry_specializations_on_festival_id"
    t.index ["industry_type"], name: "index_industry_specializations_on_industry_type"
    t.index ["specialization_code"], name: "index_industry_specializations_on_specialization_code", unique: true
    t.index ["status"], name: "index_industry_specializations_on_status"
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

  create_table "line_groups", force: :cascade do |t|
    t.bigint "line_integration_id", null: false
    t.string "line_group_id", null: false
    t.string "name", null: false
    t.text "description"
    t.boolean "is_active", default: true
    t.integer "member_count", default: 0
    t.datetime "last_activity_at"
    t.text "group_settings"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["is_active"], name: "index_line_groups_on_is_active"
    t.index ["last_activity_at"], name: "index_line_groups_on_last_activity_at"
    t.index ["line_group_id"], name: "index_line_groups_on_line_group_id", unique: true
    t.index ["line_integration_id", "line_group_id"], name: "index_line_groups_on_line_integration_id_and_line_group_id", unique: true
    t.index ["line_integration_id"], name: "index_line_groups_on_line_integration_id"
  end

  create_table "line_integrations", force: :cascade do |t|
    t.bigint "festival_id", null: false
    t.bigint "user_id", null: false
    t.string "line_channel_id", null: false
    t.string "line_channel_secret", null: false
    t.string "line_access_token", null: false
    t.string "webhook_url"
    t.text "settings"
    t.integer "status", default: 0
    t.boolean "is_active", default: false
    t.string "line_user_id"
    t.string "notification_preferences"
    t.datetime "last_sync_at"
    t.datetime "last_webhook_received_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["festival_id", "user_id"], name: "index_line_integrations_on_festival_id_and_user_id", unique: true
    t.index ["festival_id"], name: "index_line_integrations_on_festival_id"
    t.index ["is_active"], name: "index_line_integrations_on_is_active"
    t.index ["line_channel_id"], name: "index_line_integrations_on_line_channel_id", unique: true
    t.index ["status"], name: "index_line_integrations_on_status"
    t.index ["user_id"], name: "index_line_integrations_on_user_id"
  end

  create_table "line_messages", force: :cascade do |t|
    t.bigint "line_group_id", null: false
    t.bigint "user_id"
    t.string "line_message_id", null: false
    t.text "message_text", null: false
    t.string "message_type", default: "text"
    t.text "parsed_content"
    t.bigint "task_id"
    t.boolean "is_processed", default: false
    t.string "sender_line_user_id"
    t.string "sender_display_name"
    t.datetime "line_timestamp"
    t.text "processing_errors"
    t.string "intent_type"
    t.decimal "confidence_score", precision: 5, scale: 3
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["intent_type"], name: "index_line_messages_on_intent_type"
    t.index ["is_processed"], name: "index_line_messages_on_is_processed"
    t.index ["line_group_id", "line_timestamp"], name: "index_line_messages_on_line_group_id_and_line_timestamp"
    t.index ["line_group_id"], name: "index_line_messages_on_line_group_id"
    t.index ["line_message_id"], name: "index_line_messages_on_line_message_id", unique: true
    t.index ["sender_line_user_id"], name: "index_line_messages_on_sender_line_user_id"
    t.index ["task_id"], name: "index_line_messages_on_task_id"
    t.index ["user_id"], name: "index_line_messages_on_user_id"
  end

  create_table "municipal_authorities", force: :cascade do |t|
    t.string "name", null: false
    t.string "authority_type", null: false
    t.string "contact_person"
    t.string "email"
    t.string "phone"
    t.text "address"
    t.string "code"
    t.string "api_endpoint"
    t.string "api_key"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["authority_type"], name: "index_municipal_authorities_on_authority_type"
    t.index ["code"], name: "index_municipal_authorities_on_code", unique: true
    t.index ["email"], name: "index_municipal_authorities_on_email"
  end

  create_table "notification_settings", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "notification_type", null: false
    t.boolean "email_enabled", default: true
    t.boolean "web_enabled", default: true
    t.string "frequency", default: "immediate"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "line_enabled", default: false, null: false
    t.index ["line_enabled"], name: "index_notification_settings_on_line_enabled"
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
    t.string "revenue_type", default: "other", null: false
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

  create_table "tourism_collaborations", force: :cascade do |t|
    t.bigint "festival_id", null: false
    t.bigint "tourism_board_id", null: false
    t.bigint "coordinator_id", null: false
    t.string "collaboration_type", null: false
    t.string "status", default: "proposed", null: false
    t.string "priority", default: "medium"
    t.date "start_date", null: false
    t.date "end_date", null: false
    t.decimal "budget_allocation", precision: 12, scale: 2, null: false
    t.integer "expected_visitors", null: false
    t.string "collaboration_number"
    t.datetime "activated_at"
    t.datetime "completed_at"
    t.datetime "approved_at"
    t.integer "approved_by"
    t.datetime "cancelled_at"
    t.integer "cancelled_by"
    t.text "cancellation_reason"
    t.text "completion_notes"
    t.text "approval_notes"
    t.text "description"
    t.text "marketing_objectives"
    t.text "target_demographics"
    t.text "promotional_channels"
    t.text "collaboration_benefits"
    t.text "performance_metrics"
    t.text "visitor_data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["collaboration_number"], name: "index_tourism_collaborations_on_collaboration_number", unique: true
    t.index ["collaboration_type"], name: "index_tourism_collaborations_on_collaboration_type"
    t.index ["coordinator_id"], name: "index_tourism_collaborations_on_coordinator_id"
    t.index ["festival_id"], name: "index_tourism_collaborations_on_festival_id"
    t.index ["start_date", "end_date"], name: "index_tourism_collaborations_on_start_date_and_end_date"
    t.index ["status"], name: "index_tourism_collaborations_on_status"
    t.index ["tourism_board_id"], name: "index_tourism_collaborations_on_tourism_board_id"
  end

  create_table "user_preferences", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "language", limit: 10
    t.string "timezone", limit: 50
    t.text "dashboard_widgets"
    t.text "dashboard_layout"
    t.text "notification_preferences"
    t.text "theme_settings"
    t.text "quick_actions"
    t.text "favorite_features"
    t.boolean "high_contrast_mode", default: false
    t.boolean "screen_reader_optimized", default: false
    t.integer "font_scale", limit: 2, default: 100
    t.boolean "enable_animations", default: true
    t.boolean "auto_refresh_enabled", default: true
    t.integer "auto_refresh_interval", default: 30
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["high_contrast_mode"], name: "index_user_preferences_on_high_contrast_mode"
    t.index ["language"], name: "index_user_preferences_on_language"
    t.index ["screen_reader_optimized"], name: "index_user_preferences_on_screen_reader_optimized"
    t.index ["timezone"], name: "index_user_preferences_on_timezone"
    t.index ["user_id"], name: "index_user_preferences_on_user_id", unique: true
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
  add_foreign_key "api_keys", "users"
  add_foreign_key "api_requests", "api_keys"
  add_foreign_key "api_requests", "users"
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
  add_foreign_key "file_access_logs", "users"
  add_foreign_key "file_metadata", "users", column: "uploaded_by_id"
  add_foreign_key "forum_posts", "forum_threads"
  add_foreign_key "forum_posts", "users"
  add_foreign_key "forum_threads", "forums"
  add_foreign_key "forum_threads", "users"
  add_foreign_key "forums", "festivals"
  add_foreign_key "industry_specializations", "festivals"
  add_foreign_key "layout_elements", "venues"
  add_foreign_key "line_groups", "line_integrations"
  add_foreign_key "line_integrations", "festivals"
  add_foreign_key "line_integrations", "users"
  add_foreign_key "line_messages", "line_groups"
  add_foreign_key "line_messages", "tasks"
  add_foreign_key "line_messages", "users"
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
  add_foreign_key "tourism_collaborations", "festivals"
  add_foreign_key "tourism_collaborations", "municipal_authorities", column: "tourism_board_id"
  add_foreign_key "tourism_collaborations", "users", column: "coordinator_id"
  add_foreign_key "user_preferences", "users"
  add_foreign_key "vendor_applications", "festivals"
  add_foreign_key "vendor_applications", "users"
  add_foreign_key "venue_areas", "venues"
  add_foreign_key "venues", "festivals"
end
