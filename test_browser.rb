require "playwright"

Playwright.connect_to_browser_server(
  "ws://127.0.0.1:8080/ws"
) do |browser|

  page = browser.new_page

  page.goto("https://example.com")

  puts "Browser opened successfully."
  puts "Title: #{page.title}"

  sleep 5
end