class CreateTravelAssistantSchema < ActiveRecord::Migration[7.2]
  def up
    create_table :conversations do |t|
      t.text :preferences, null: false

      t.timestamps
    end

    create_table :messages do |t|
      t.references :conversation, null: false, foreign_key: true
      t.string :role, null: false
      t.text :content, null: false
      t.text :metadata, null: false

      t.timestamps
    end

    create_table :knowledge_sources do |t|
      t.string :title, null: false
      t.string :url, null: false
      t.string :destination, null: false
      t.string :source_type, null: false
      t.text :metadata, null: false

      t.timestamps
    end

    create_table :knowledge_chunks do |t|
      t.references :knowledge_source, null: false, foreign_key: true
      t.integer :chunk_index, null: false
      t.text :content, null: false
      t.float :embedding, array: true, null: false
      t.text :metadata, null: false

      t.timestamps
    end

    add_index :messages, %i[conversation_id created_at]
    add_index :knowledge_sources, %i[destination source_type]
    add_index :knowledge_chunks, %i[knowledge_source_id chunk_index], unique: true
    add_index :knowledge_chunks, :embedding, using: :gin
  end

  def down
    remove_index :knowledge_chunks, :embedding
    drop_table :knowledge_chunks
    drop_table :knowledge_sources
    drop_table :messages
    drop_table :conversations
  end
end
