class SearchDocumentsTool < RubyLLM::Tool
  desc "Search the user's uploaded documents for information relevant to a question."

  param :query, desc: "The information to search for"

  def execute(query:)
    results = DocumentSearch.search(query, limit: 3)

    if results.empty?
      return "No relevant information was found in the uploaded documents."
    end

    results.map do |chunk|
      "SOURCE: #{chunk.document.filename}\nCONTENT: #{chunk.content}"
    end.join("\n\n---\n\n")
  end
end