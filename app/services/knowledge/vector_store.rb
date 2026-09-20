module Knowledge
  class VectorStore
    def search(query_vector:, destination:, top_k:)
      KnowledgeChunk
        .includes(:knowledge_source)
        .joins(:knowledge_source)
        .where(knowledge_sources: { destination: destination })
        .to_a
        .sort_by { |chunk| 1.0 - cosine_similarity(query_vector, chunk.embedding) }
        .first(top_k)
    end

    private

    def cosine_similarity(left, right)
      return 0.0 if left.blank? || right.blank?

      dot = left.zip(right).sum { |a, b| a.to_f * b.to_f }
      left_magnitude = Math.sqrt(left.sum { |value| value.to_f**2 })
      right_magnitude = Math.sqrt(right.sum { |value| value.to_f**2 })
      return 0.0 if left_magnitude.zero? || right_magnitude.zero?

      dot / (left_magnitude * right_magnitude)
    end
  end
end
