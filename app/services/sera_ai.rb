class SeraAi
  def self.call(message)
    client = OpenAI::Client.new

    response = client.responses.create(
      parameters: {
        model: "gpt-5",
        input: message
      }
    )

    response.dig("output", 1, "content", 0, "text")
  end
end