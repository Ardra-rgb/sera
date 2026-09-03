require "faraday"
require "json"

class GeminiService
  MODEL = "gemini-3.6-flash"

  def self.generate(prompt)
    response = Faraday.post(
      "https://generativelanguage.googleapis.com/v1beta/models/#{MODEL}:generateContent",
      {
        contents: [
          {
            parts: [
              { text: prompt }
            ]
          }
        ]
      }.to_json,
      {
        "Content-Type" => "application/json",
        "x-goog-api-key" => ENV["GEMINI_API_KEY"]
      }
    )

    body = JSON.parse(response.body)

    unless response.success?
      raise "Gemini API error: #{body.dig("error", "message") || response.body}"
    end

    body.dig("candidates", 0, "content", "parts", 0, "text")
  end
end
