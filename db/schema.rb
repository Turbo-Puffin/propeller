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

ActiveRecord::Schema[8.1].define(version: 2026_04_08_103504) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "accounts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "plan", default: 0, null: false
    t.jsonb "settings", default: {}
    t.integer "status", default: 0, null: false
    t.string "subdomain", null: false
    t.datetime "updated_at", null: false
    t.index ["plan"], name: "index_accounts_on_plan"
    t.index ["status"], name: "index_accounts_on_status"
    t.index ["subdomain"], name: "index_accounts_on_subdomain", unique: true
  end

  create_table "campaign_sends", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "bounced_at"
    t.uuid "campaign_id", null: false
    t.datetime "clicked_at"
    t.uuid "contact_id", null: false
    t.datetime "created_at", null: false
    t.datetime "opened_at"
    t.datetime "sent_at"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["campaign_id", "contact_id"], name: "index_campaign_sends_on_campaign_id_and_contact_id", unique: true
    t.index ["campaign_id"], name: "index_campaign_sends_on_campaign_id"
    t.index ["contact_id"], name: "index_campaign_sends_on_contact_id"
    t.index ["status"], name: "index_campaign_sends_on_status"
  end

  create_table "campaigns", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.text "body_html"
    t.text "body_text"
    t.integer "campaign_type", default: 0, null: false
    t.datetime "created_at", null: false
    t.string "from_email"
    t.string "from_name"
    t.string "name", null: false
    t.datetime "scheduled_at"
    t.datetime "sent_at"
    t.jsonb "settings", default: {}
    t.integer "status", default: 0, null: false
    t.string "subject"
    t.datetime "updated_at", null: false
    t.index ["account_id", "status"], name: "index_campaigns_on_account_id_and_status"
    t.index ["account_id"], name: "index_campaigns_on_account_id"
    t.index ["campaign_type"], name: "index_campaigns_on_campaign_type"
    t.index ["status"], name: "index_campaigns_on_status"
  end

  create_table "contact_list_memberships", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "contact_id", null: false
    t.uuid "contact_list_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["contact_id", "contact_list_id"], name: "idx_contact_list_memberships_unique", unique: true
    t.index ["contact_id"], name: "index_contact_list_memberships_on_contact_id"
    t.index ["contact_list_id"], name: "index_contact_list_memberships_on_contact_list_id"
  end

  create_table "contact_lists", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.jsonb "auto_segment_rules", default: {}
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "name"], name: "index_contact_lists_on_account_id_and_name"
    t.index ["account_id"], name: "index_contact_lists_on_account_id"
  end

  create_table "contacts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "first_name"
    t.string "last_name"
    t.jsonb "metadata", default: {}
    t.integer "status", default: 0, null: false
    t.datetime "subscribed_at"
    t.datetime "unsubscribed_at"
    t.datetime "updated_at", null: false
    t.index ["account_id", "email"], name: "index_contacts_on_account_id_and_email", unique: true
    t.index ["account_id"], name: "index_contacts_on_account_id"
    t.index ["email"], name: "index_contacts_on_email"
    t.index ["status"], name: "index_contacts_on_status"
  end

  create_table "email_sequence_enrollments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "completed_at"
    t.uuid "contact_id", null: false
    t.datetime "created_at", null: false
    t.integer "current_step", default: 0, null: false
    t.uuid "email_sequence_id", null: false
    t.datetime "enrolled_at"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["contact_id"], name: "index_email_sequence_enrollments_on_contact_id"
    t.index ["email_sequence_id", "contact_id"], name: "idx_email_seq_enrollments_unique", unique: true
    t.index ["email_sequence_id"], name: "index_email_sequence_enrollments_on_email_sequence_id"
    t.index ["status"], name: "index_email_sequence_enrollments_on_status"
  end

  create_table "email_sequence_steps", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "body_html"
    t.text "body_text"
    t.datetime "created_at", null: false
    t.integer "delay_hours", default: 0, null: false
    t.uuid "email_sequence_id", null: false
    t.integer "position", null: false
    t.jsonb "settings", default: {}
    t.string "subject", null: false
    t.datetime "updated_at", null: false
    t.index ["email_sequence_id", "position"], name: "idx_email_sequence_steps_on_sequence_and_position", unique: true
    t.index ["email_sequence_id"], name: "index_email_sequence_steps_on_email_sequence_id"
  end

  create_table "email_sequences", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.integer "status", default: 0, null: false
    t.integer "trigger_type", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "status"], name: "index_email_sequences_on_account_id_and_status"
    t.index ["account_id"], name: "index_email_sequences_on_account_id"
    t.index ["trigger_type"], name: "index_email_sequences_on_trigger_type"
  end

  create_table "form_submissions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "contact_id"
    t.datetime "created_at", null: false
    t.jsonb "data", default: {}
    t.uuid "form_id", null: false
    t.string "ip_address"
    t.datetime "submitted_at"
    t.datetime "updated_at", null: false
    t.index ["contact_id"], name: "index_form_submissions_on_contact_id"
    t.index ["form_id"], name: "index_form_submissions_on_form_id"
    t.index ["submitted_at"], name: "index_form_submissions_on_submitted_at"
  end

  create_table "forms", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.datetime "created_at", null: false
    t.integer "form_type", default: 0, null: false
    t.text "html_content"
    t.string "name", null: false
    t.string "redirect_url"
    t.jsonb "settings", default: {}
    t.integer "status", default: 0, null: false
    t.text "success_message"
    t.datetime "updated_at", null: false
    t.index ["account_id", "status"], name: "index_forms_on_account_id_and_status"
    t.index ["account_id"], name: "index_forms_on_account_id"
    t.index ["form_type"], name: "index_forms_on_form_type"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.datetime "confirmed_at"
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "name", null: false
    t.string "password_digest", null: false
    t.integer "role", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_users_on_account_id"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["role"], name: "index_users_on_role"
  end

  create_table "waitlist_entries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_waitlist_entries_on_email", unique: true
  end

  add_foreign_key "campaign_sends", "campaigns"
  add_foreign_key "campaign_sends", "contacts"
  add_foreign_key "campaigns", "accounts"
  add_foreign_key "contact_list_memberships", "contact_lists"
  add_foreign_key "contact_list_memberships", "contacts"
  add_foreign_key "contact_lists", "accounts"
  add_foreign_key "contacts", "accounts"
  add_foreign_key "email_sequence_enrollments", "contacts"
  add_foreign_key "email_sequence_enrollments", "email_sequences"
  add_foreign_key "email_sequence_steps", "email_sequences"
  add_foreign_key "email_sequences", "accounts"
  add_foreign_key "form_submissions", "contacts"
  add_foreign_key "form_submissions", "forms"
  add_foreign_key "forms", "accounts"
  add_foreign_key "users", "accounts"
end
