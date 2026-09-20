class AddHashDefaultsToTravelAssistantColumns < ActiveRecord::Migration[7.2]
  def up
    execute <<~SQL
      UPDATE conversations SET preferences = '{}' WHERE preferences IS NULL;
      UPDATE messages SET metadata = '{}' WHERE metadata IS NULL;
      UPDATE knowledge_sources SET metadata = '{}' WHERE metadata IS NULL;
      UPDATE knowledge_chunks SET metadata = '{}' WHERE metadata IS NULL;
    SQL

    change_column_default :conversations, :preferences, from: nil, to: "{}"
    change_column_default :messages, :metadata, from: nil, to: "{}"
    change_column_default :knowledge_sources, :metadata, from: nil, to: "{}"
    change_column_default :knowledge_chunks, :metadata, from: nil, to: "{}"
  end

  def down
    change_column_default :conversations, :preferences, from: "{}", to: nil
    change_column_default :messages, :metadata, from: "{}", to: nil
    change_column_default :knowledge_sources, :metadata, from: "{}", to: nil
    change_column_default :knowledge_chunks, :metadata, from: "{}", to: nil
  end
end
