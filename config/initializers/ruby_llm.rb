RubyLLM.configure do |config|
  config.gemini_api_key = ENV["GEMINI_API_KEY"]

  config.openai_api_key = ENV["GROQ_API_KEY"]
  config.openai_api_base = "https://api.groq.com/openai/v1"
end