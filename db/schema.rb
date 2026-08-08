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

ActiveRecord::Schema[7.2].define(version: 2026_08_08_114015) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "configurations", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "github_access_token"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "gitlab_access_token"
    t.string "gitlab_url"
    t.index ["user_id"], name: "index_configurations_on_user_id"
  end

  create_table "contributors", force: :cascade do |t|
    t.string "github_login", null: false
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "active", default: true
    t.index ["github_login"], name: "index_contributors_on_github_login", unique: true
  end

  create_table "file_changes", force: :cascade do |t|
    t.bigint "pull_request_id", null: false
    t.bigint "contributor_id", null: false
    t.string "path", null: false
    t.string "tech", null: false
    t.integer "lines_changed", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["contributor_id", "tech"], name: "index_file_changes_on_contributor_id_and_tech"
    t.index ["contributor_id"], name: "index_file_changes_on_contributor_id"
    t.index ["pull_request_id"], name: "index_file_changes_on_pull_request_id"
  end

  create_table "file_extension_mappings", force: :cascade do |t|
    t.string "extension", null: false
    t.string "tech", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["extension"], name: "index_file_extension_mappings_on_extension", unique: true
  end

  create_table "holidays", force: :cascade do |t|
    t.datetime "start_date", null: false
    t.datetime "end_date", null: false
    t.bigint "contributor_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["contributor_id"], name: "index_holidays_on_contributor_id"
  end

  create_table "pull_requests", force: :cascade do |t|
    t.bigint "repository_id", null: false
    t.bigint "author_id", null: false
    t.integer "github_number", null: false
    t.string "title"
    t.string "state", default: "open", null: false
    t.datetime "opened_at", null: false
    t.datetime "merged_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["author_id"], name: "index_pull_requests_on_author_id"
    t.index ["repository_id", "github_number"], name: "index_pull_requests_on_repository_id_and_github_number", unique: true
    t.index ["repository_id"], name: "index_pull_requests_on_repository_id"
  end

  create_table "repositories", force: :cascade do |t|
    t.string "github_full_name", null: false
    t.string "webhook_secret", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.string "provider", default: "github", null: false
    t.index ["github_full_name"], name: "index_repositories_on_github_full_name", unique: true
    t.index ["user_id"], name: "index_repositories_on_user_id"
  end

  create_table "repository_contributors", force: :cascade do |t|
    t.bigint "repository_id", null: false
    t.bigint "contributor_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["contributor_id"], name: "index_repository_contributors_on_contributor_id"
    t.index ["repository_id", "contributor_id"], name: "idx_on_repository_id_contributor_id_a09a6bb9b7", unique: true
    t.index ["repository_id"], name: "index_repository_contributors_on_repository_id"
  end

  create_table "review_assignments", force: :cascade do |t|
    t.bigint "pull_request_id", null: false
    t.bigint "reviewer_id", null: false
    t.datetime "assigned_at", null: false
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "matched_tech"
    t.index ["pull_request_id"], name: "index_review_assignments_on_pull_request_id"
    t.index ["reviewer_id"], name: "index_review_assignments_on_reviewer_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "configurations", "users"
  add_foreign_key "file_changes", "contributors"
  add_foreign_key "file_changes", "pull_requests"
  add_foreign_key "pull_requests", "contributors", column: "author_id"
  add_foreign_key "pull_requests", "repositories"
  add_foreign_key "repository_contributors", "contributors"
  add_foreign_key "repository_contributors", "repositories"
  add_foreign_key "review_assignments", "contributors", column: "reviewer_id"
  add_foreign_key "review_assignments", "pull_requests"
end
