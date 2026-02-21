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

ActiveRecord::Schema[7.2].define(version: 2026_02_21_000022) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

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

  create_table "campaign_deliveries", force: :cascade do |t|
    t.bigint "campaign_id", null: false
    t.bigint "recipient_user_id", null: false
    t.bigint "message_id"
    t.integer "status", default: 0, null: false
    t.string "clicked_button_label"
    t.string "clicked_list_row_id"
    t.datetime "delivered_at"
    t.datetime "read_at"
    t.datetime "clicked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["campaign_id", "recipient_user_id"], name: "index_campaign_deliveries_on_campaign_id_and_recipient_user_id", unique: true
    t.index ["campaign_id"], name: "index_campaign_deliveries_on_campaign_id"
    t.index ["message_id"], name: "index_campaign_deliveries_on_message_id"
    t.index ["recipient_user_id"], name: "index_campaign_deliveries_on_recipient_user_id"
  end

  create_table "companies", force: :cascade do |t|
    t.bigint "owner_id", null: false
    t.string "name", null: false
    t.string "nickname", null: false
    t.string "description"
    t.text "bio"
    t.integer "status", default: 0, null: false
    t.jsonb "menu_config", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["nickname"], name: "index_companies_on_nickname", unique: true
    t.index ["owner_id"], name: "index_companies_on_owner_id"
  end

  create_table "company_attendants", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "user_id", null: false
    t.string "role_name"
    t.integer "attendant_type", default: 0, null: false
    t.jsonb "tags", default: [], null: false
    t.integer "status", default: 0, null: false
    t.boolean "is_supervisor", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "user_id"], name: "index_company_attendants_on_company_id_and_user_id", unique: true
    t.index ["company_id"], name: "index_company_attendants_on_company_id"
    t.index ["status"], name: "index_company_attendants_on_status"
    t.index ["user_id"], name: "index_company_attendants_on_user_id"
  end

  create_table "contact_requests", force: :cascade do |t|
    t.bigint "sender_id", null: false
    t.bigint "receiver_id", null: false
    t.integer "status", default: 0, null: false
    t.string "preview_text"
    t.string "preview_type"
    t.bigint "pending_message_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["receiver_id"], name: "index_contact_requests_on_receiver_id"
    t.index ["sender_id", "receiver_id"], name: "index_contact_requests_on_sender_id_and_receiver_id", unique: true
    t.index ["sender_id"], name: "index_contact_requests_on_sender_id"
  end

  create_table "conversation_assignments", force: :cascade do |t|
    t.bigint "conversation_id", null: false
    t.bigint "company_id", null: false
    t.bigint "company_attendant_id"
    t.integer "status", default: 0, null: false
    t.string "selected_department"
    t.datetime "assigned_at"
    t.datetime "resolved_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_attendant_id"], name: "index_conversation_assignments_on_company_attendant_id"
    t.index ["company_id"], name: "index_conversation_assignments_on_company_id"
    t.index ["conversation_id"], name: "index_conversation_assignments_on_conversation_id"
    t.index ["status"], name: "index_conversation_assignments_on_status"
  end

  create_table "conversations", force: :cascade do |t|
    t.string "name"
    t.integer "conversation_type", default: 0, null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "company_id"
    t.boolean "is_company_conversation", default: false, null: false
    t.index ["company_id"], name: "index_conversations_on_company_id"
  end

  create_table "marketing_campaigns", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "marketing_template_id", null: false
    t.string "name", null: false
    t.integer "status", default: 0, null: false
    t.jsonb "recipient_identifiers", default: [], null: false
    t.integer "daily_limit", default: 1000
    t.datetime "scheduled_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["marketing_template_id"], name: "index_marketing_campaigns_on_marketing_template_id"
    t.index ["user_id"], name: "index_marketing_campaigns_on_user_id"
  end

  create_table "marketing_templates", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "name", null: false
    t.string "header_type", default: "none"
    t.string "header_text"
    t.text "body", null: false
    t.string "footer"
    t.jsonb "buttons", default: [], null: false
    t.jsonb "list_header"
    t.jsonb "list_sections", default: [], null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_marketing_templates_on_user_id"
  end

  create_table "message_reactions", force: :cascade do |t|
    t.bigint "message_id", null: false
    t.bigint "user_id", null: false
    t.string "emoji", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["message_id", "user_id", "emoji"], name: "index_message_reactions_on_message_id_and_user_id_and_emoji", unique: true
    t.index ["message_id"], name: "index_message_reactions_on_message_id"
    t.index ["user_id"], name: "index_message_reactions_on_user_id"
  end

  create_table "messages", force: :cascade do |t|
    t.bigint "conversation_id", null: false
    t.bigint "sender_id", null: false
    t.text "content"
    t.integer "message_type", default: 0, null: false
    t.integer "status", default: 0, null: false
    t.bigint "reply_to_id"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "deleted_at"
    t.boolean "deleted_for_everyone", default: false, null: false
    t.bigint "forwarded_from_id"
    t.boolean "message_type_marketing", default: false, null: false
    t.bigint "campaign_delivery_id"
    t.index ["conversation_id"], name: "index_messages_on_conversation_id"
    t.index ["created_at"], name: "index_messages_on_created_at"
    t.index ["deleted_at"], name: "index_messages_on_deleted_at"
    t.index ["forwarded_from_id"], name: "index_messages_on_forwarded_from_id"
    t.index ["metadata"], name: "index_messages_on_metadata", using: :gin
    t.index ["reply_to_id"], name: "index_messages_on_reply_to_id"
    t.index ["sender_id"], name: "index_messages_on_sender_id"
  end

  create_table "participants", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "conversation_id", null: false
    t.integer "role", default: 0, null: false
    t.datetime "last_read_at"
    t.boolean "muted", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "archived", default: false, null: false
    t.boolean "pinned", default: false, null: false
    t.datetime "interactive_locked_until"
    t.bigint "interactive_message_id"
    t.index ["archived"], name: "index_participants_on_archived"
    t.index ["conversation_id"], name: "index_participants_on_conversation_id"
    t.index ["pinned"], name: "index_participants_on_pinned"
    t.index ["user_id", "conversation_id"], name: "index_participants_on_user_id_and_conversation_id", unique: true
    t.index ["user_id"], name: "index_participants_on_user_id"
  end

  create_table "read_receipts", force: :cascade do |t|
    t.bigint "message_id", null: false
    t.bigint "user_id", null: false
    t.datetime "read_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["message_id", "user_id"], name: "index_read_receipts_on_message_id_and_user_id", unique: true
    t.index ["message_id"], name: "index_read_receipts_on_message_id"
    t.index ["user_id"], name: "index_read_receipts_on_user_id"
  end

  create_table "templates", force: :cascade do |t|
    t.string "name", null: false
    t.string "category", default: "general", null: false
    t.text "content", null: false
    t.jsonb "variables", default: [], null: false
    t.bigint "created_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_templates_on_created_by_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.string "display_name", default: "", null: false
    t.string "phone"
    t.text "bio"
    t.boolean "online", default: false, null: false
    t.datetime "last_seen_at"
    t.string "jti", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "role", default: 0, null: false
    t.string "nickname"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["jti"], name: "index_users_on_jti", unique: true
    t.index ["nickname"], name: "index_users_on_nickname", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["role"], name: "index_users_on_role"
  end

  create_table "web_push_subscriptions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "endpoint", null: false
    t.string "p256dh", null: false
    t.string "auth", null: false
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["endpoint"], name: "index_web_push_subscriptions_on_endpoint", unique: true
    t.index ["user_id"], name: "index_web_push_subscriptions_on_user_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "campaign_deliveries", "marketing_campaigns", column: "campaign_id"
  add_foreign_key "campaign_deliveries", "messages"
  add_foreign_key "campaign_deliveries", "users", column: "recipient_user_id"
  add_foreign_key "companies", "users", column: "owner_id"
  add_foreign_key "company_attendants", "companies"
  add_foreign_key "company_attendants", "users"
  add_foreign_key "contact_requests", "users", column: "receiver_id"
  add_foreign_key "contact_requests", "users", column: "sender_id"
  add_foreign_key "conversation_assignments", "companies"
  add_foreign_key "conversation_assignments", "company_attendants"
  add_foreign_key "conversation_assignments", "conversations"
  add_foreign_key "marketing_campaigns", "marketing_templates"
  add_foreign_key "marketing_campaigns", "users"
  add_foreign_key "marketing_templates", "users"
  add_foreign_key "message_reactions", "messages"
  add_foreign_key "message_reactions", "users"
  add_foreign_key "messages", "conversations"
  add_foreign_key "messages", "messages", column: "forwarded_from_id"
  add_foreign_key "messages", "messages", column: "reply_to_id"
  add_foreign_key "messages", "users", column: "sender_id"
  add_foreign_key "participants", "conversations"
  add_foreign_key "participants", "users"
  add_foreign_key "read_receipts", "messages"
  add_foreign_key "read_receipts", "users"
  add_foreign_key "templates", "users", column: "created_by_id"
  add_foreign_key "web_push_subscriptions", "users"
end
