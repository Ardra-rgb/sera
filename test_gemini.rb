require "faraday"
require "json"

response = Faraday.post(
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.6-flash:generateContent",
  {
    contents: [
      {
        parts: [
          { text: "Say hello in one short sentence." }
        ]
      }
    ]
  }.to_json,
  {
    "Content-Type" => "application/json",
    "x-goog-api-key" => ENV["GEMINI_API_KEY"]
  }
)

puts "Status: #{response.status}"
puts response.body