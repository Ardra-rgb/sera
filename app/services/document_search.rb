class DocumentSearch
  def self.search(query, limit: 3)
    query_vector = RubyLLM.embed(
      query,
      model: "gemini-embedding-001",
      provider: :gemini,
      assume_model_exists: true
    ).vectors

    DocumentChunk.where.not(embedding: nil)
                 .sort_by do |chunk|
      -cosine_similarity(
        query_vector,
        JSON.parse(chunk.embedding)
      )
    end
                 .first(limit)
  end

  def self.cosine_similarity(a, b)
    dot_product = a.zip(b).sum { |x, y| x * y }

    magnitude_a = Math.sqrt(a.sum { |x| x * x })
    magnitude_b = Math.sqrt(b.sum { |x| x * x })

    return 0.0 if magnitude_a.zero? || magnitude_b.zero?

    dot_product / (magnitude_a * magnitude_b)
  end

  private_class_method :cosine_similarity
end