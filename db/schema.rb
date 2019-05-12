# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2019_05_04_141522) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_trgm"
  enable_extension "plpgsql"

  create_table "delayed_jobs", force: :cascade do |t|
    t.integer "priority", default: 0, null: false
    t.integer "attempts", default: 0, null: false
    t.text "handler", null: false
    t.text "last_error"
    t.datetime "run_at"
    t.datetime "locked_at"
    t.datetime "failed_at"
    t.string "locked_by"
    t.string "queue"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["priority", "run_at"], name: "delayed_jobs_priority"
  end

  create_table "hn_items", force: :cascade do |t|
    t.bigint "hn_id", null: false
    t.date "front_page_date", null: false
    t.integer "front_page_ranking", null: false
    t.text "submitted_by"
    t.datetime "submitted_at"
    t.text "title"
    t.text "url"
    t.integer "score"
    t.integer "comments_count"
    t.text "item_type"
    t.text "domain"
    t.text "domain_with_subdomain"
    t.tsvector "tsv"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "lower(domain)", name: "index_hn_items_on_lower_domain"
    t.index "lower(domain_with_subdomain)", name: "index_hn_items_on_lower_domain_with_subdomain"
    t.index ["domain"], name: "index_hn_items_on_domain"
    t.index ["domain_with_subdomain"], name: "index_hn_items_on_domain_with_subdomain"
    t.index ["hn_id"], name: "index_hn_items_on_hn_id", unique: true
    t.index ["submitted_by"], name: "index_hn_items_on_submitted_by"
    t.index ["title"], name: "index_hn_items_on_title", opclass: :gin_trgm_ops, using: :gin
    t.index ["tsv"], name: "index_hn_items_on_tsv", using: :gin
  end

end
