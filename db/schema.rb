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

ActiveRecord::Schema[7.2].define(version: 2026_09_20_000002) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "conversations", force: :cascade do |t|
    t.text "preferences", default: "{}", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "knowledge_chunks", force: :cascade do |t|
    t.bigint "knowledge_source_id", null: false
    t.integer "chunk_index", null: false
    t.text "content", null: false
    t.float "embedding", null: false, array: true
    t.text "metadata", default: "{}", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["embedding"], name: "index_knowledge_chunks_on_embedding", using: :gin
    t.index ["knowledge_source_id", "chunk_index"], name: "index_knowledge_chunks_on_knowledge_source_id_and_chunk_index", unique: true
    t.index ["knowledge_source_id"], name: "index_knowledge_chunks_on_knowledge_source_id"
  end

  create_table "knowledge_sources", force: :cascade do |t|
    t.string "title", null: false
    t.string "url", null: false
    t.string "destination", null: false
    t.string "source_type", null: false
    t.text "metadata", default: "{}", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["destination", "source_type"], name: "index_knowledge_sources_on_destination_and_source_type"
  end

  create_table "messages", force: :cascade do |t|
    t.bigint "conversation_id", null: false
    t.string "role", null: false
    t.text "content", null: false
    t.text "metadata", default: "{}", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["conversation_id", "created_at"], name: "index_messages_on_conversation_id_and_created_at"
    t.index ["conversation_id"], name: "index_messages_on_conversation_id"
  end

  add_foreign_key "knowledge_chunks", "knowledge_sources"
  add_foreign_key "messages", "conversations"
end
