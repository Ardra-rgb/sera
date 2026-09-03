require "playwright"
require "socket"
require "fileutils"
require "uri"


class BrowserApplicationTool < RubyLLM::Tool
    @browser = nil
    @page = nil
    @playwright = nil

    class << self
      attr_accessor :browser, :page, :playwright
    end
  desc(
    "Use a real browser to search the web, open websites, inspect links, " \
    "click links or buttons, and download files. Use this for browser tasks " \
    "requested by the user."
  )

  param :action,
    desc: "The action: search, open, inspect_links, click, download_options, download, fill, human_help, review, or submit"
  param :application_name,
        desc: "The name of the application or task"

  param :url,
        desc: "Optional URL to open or download from"

  param :query,
        desc: "Optional web search query"

  param :selection, desc: "The specific download option selected by the user"

  def execute(
    action:,
    application_name:,
    url: nil,
    query: nil,
    link_text: nil,
    selection: nil
  )
    task = ApplicationTask.find_or_initialize_by(
      application_name: application_name
    )

    case action
    when "search"
      search_query = query.presence ||
                     "#{application_name} official website"

      browser_result = with_browser do |page|
        page.goto(
          "https://www.google.com/search?q=#{URI.encode_www_form_component(search_query)}"
        )

        {
          title: page.title,
          url: page.url,
          text: page.locator("body").inner_text[0, 5000]
        }
      end

      if browser_result[:text].match?(
        /unusual traffic|verify.*human|captcha|robot/i
      )
        task.status = "waiting_for_user"
        task.details =
          "The website requires human verification before SERA can continue."
        task.save!

        return(
          "Human verification is required. Ask the user to complete the " \
          "verification in the browser, then wait for the user to continue."
        )
      end

      task.status = "preparing"
      task.details =
        "Searched the web for the official #{application_name} website."
      task.save!

      <<~RESULT
        Browser search completed.

        Search query: #{search_query}
        Page title: #{browser_result[:title]}
        Page URL: #{browser_result[:url]}

        Search results:
        #{browser_result[:text]}

        Inspect the results and identify the official website.
        Do not submit or install anything yet.
      RESULT

    when "open"
      return "A URL is required." if url.blank?

      browser_result = with_browser do |page|
        page.goto(url)

        {
          title: page.title,
          url: page.url,
          text: page.locator("body").inner_text[0, 5000]
        }
      end

      task.status = "preparing"
      task.details =
        "Opened the application website: #{browser_result[:url]}"
      task.save!

      <<~RESULT
        Application website opened.

        Title: #{browser_result[:title]}
        URL: #{browser_result[:url]}

        Visible page text:
        #{browser_result[:text]}

        Inspect the page before performing any further action.
      RESULT

    when "inspect_links"
      current_url = extract_url(task.details)

      return "No application page is currently open." if current_url.blank?

      browser_result = with_browser do |page|
        page.goto(current_url)

        links = page.locator("a").all.map do |link|
          {
            text: link.inner_text.strip,
            href: link.get_attribute("href")
          }
        end.reject do |link|
          link[:text].blank?
        end

        {
          title: page.title,
          url: page.url,
          links: links.first(100)
        }
      end

      <<~RESULT
        Links found on the application page.

        Page: #{browser_result[:title]}
        URL: #{browser_result[:url]}

        #{browser_result[:links].map { |link|
          "#{link[:text]} -> #{link[:href]}"
        }.join("\n")}
      RESULT

    when "click"
      return "Link text is required." if link_text.blank?

      current_url = extract_url(task.details)

      return(
        "No application page is currently open. Open the application first."
      ) if current_url.blank?

      browser_result = with_browser do |page|
        page.goto(current_url)

        element = page.get_by_text(link_text)

        if element.count.zero?
          {
            error: "No element containing that text was found.",
            title: page.title,
            url: page.url,
            text: page.locator("body").inner_text[0, 5000]
          }
        else
          element.first.click

          {
            title: page.title,
            url: page.url,
            text: page.locator("body").inner_text[0, 5000]
          }
        end
      end

      return browser_result[:error] if browser_result[:error]

      task.status = "preparing"
      task.details = "Navigated to: #{browser_result[:url]}"
      task.save!

      <<~RESULT
        Browser action completed.

        Clicked: #{link_text}
        Page title: #{browser_result[:title]}
        Page URL: #{browser_result[:url]}

        Visible page text:
        #{browser_result[:text]}

        Inspect the new page before continuing.
      RESULT


    when "download_options"
      current_url = url.presence || extract_url(task.details)

      return "A URL is required." if current_url.blank?

      browser_result = with_browser do |page|
        page.goto(current_url)

        candidates = page.locator("a, button").all.map do |element|
          text = element.inner_text.strip
          href = element.get_attribute("href")

          {
            text: text,
            href: href
          }
        end.reject do |item|
          item[:text].blank? || item[:href].blank?
        end.select do |item|
          item[:text].match?(/download/i) ||
            item[:href].match?(/\.(exe|msi|deb|rpm|dmg|apk|flatpak|pkg|zip)\b/i)
        end

        {
          title: page.title,
          url: page.url,
          options: candidates.first(50)
        }
       end

      if browser_result[:options].empty?
        return "I couldn't find any clear download options on this page."
      end

      options = browser_result[:options].each_with_index.map do |option, index|
        href = option[:href]

        filename =
          if href
            URI.parse(href).path.split("/").last
          end

        description =
          if filename.present?
            filename
              .gsub(/[-_]+/, " ")
              .sub(/\.(exe|msi|deb|rpm|dmg|apk|flatpak|pkg|zip)$/i, " \\0")
          else
            option[:text]
          end

        "#{index + 1}. #{description}"
      end

      <<~RESULT
        I found multiple possible download options:

        #{options.join("\n")}

        Ask the user which specific option they want.
        Do not select one automatically.
      RESULT

    when "download"
      return "A URL is required for downloading." if url.blank?
      return "A download link or button text is required." if link_text.blank?

      download_dir = Rails.root.join("tmp", "sera_downloads")
      FileUtils.mkdir_p(download_dir)

      browser_result = with_browser do |page|
        page.goto(url)

        element = page.get_by_text(link_text)

        if element.count.zero?
          {
            error: "No download link or button containing '#{link_text}' was found.",
            title: page.title,
            url: page.url,
            text: page.locator("body").inner_text[0, 5000]
          }
        else
          download = page.expect_download do
            element.first.click
          end
          filename = download.suggested_filename
          destination = download_dir.join(filename)

          download.save_as(destination.to_s)

          {
            filename: filename,
            path: destination.to_s,
            url: download.url,
            title: page.title
          }
        end
      end

      if browser_result[:error]
        return browser_result[:error]
      end

      task.status = "waiting_for_user"
      task.details =
        "File downloaded to #{browser_result[:path]}. " \
        "User approval is required before running it."
      task.save!

      <<~RESULT
        Download completed.

        File: #{browser_result[:filename]}
        Saved to: #{browser_result[:path]}
        Download URL: #{browser_result[:url]}

        The file has been downloaded but NOT executed.
        Ask the user for explicit approval before running the installer.
      RESULT

    when "continue"
      browser_result = with_browser do |page|
        {
          title: page.title,
        url: page.url,
        text: page.locator("body").inner_text[0, 5000]
      }
    end

    task.status = "preparing"
    task.details = "Human verification completed. Browser is ready to continue from #{browser_result[:url]}."
    task.save!

    <<~RESULT
      Browser session resumed.

      Page title: #{browser_result[:title]}
      Page URL: #{browser_result[:url]}

      Visible page text:
      #{browser_result[:text]}

      Continue the requested browser task from the current page.
    RESULT

    when "fill"
      task.status = "preparing"
      task.details =
        "Application fields are being prepared using available information."
      task.save!

      "The application form is ready to be filled using available stored information."

    when "human_help"
      task.status = "waiting_for_user"
      task.details =
        "Human action is required for CAPTCHA, OTP, payment authorization, " \
        "identity verification, or another protected step."
      task.save!

      "Human action is required. Ask the user to complete the protected step and wait for confirmation."

    when "review"
      task.status = "ready_for_review"
      task.details =
        "Application is filled and waiting for the user's review."
      task.save!

      "The application is ready for review. Ask the user to verify the information before submission."

    when "submit"
      if task.status != "approved"
        return "The application has not been explicitly approved for submission."
      end

      task.status = "submitted"
      task.details =
        "Application submission completed successfully."
      task.save!

      "The application was submitted successfully."

    else
      "Unknown browser action: #{action}"
    end
  end

  private

  def with_browser
    unless browser_server_available?
      raise "Playwright server is not running on 127.0.0.1:8080."
    end

    Playwright.connect_to_browser_server(
     "ws://127.0.0.1:8080/ws"
    ) do |browser|
      context = browser.contexts.first

      page =
        if context && !context.pages.empty?
          context.pages.first
        elsif context
          context.new_page
        else
          browser.new_page
        end

      yield page
    end
  end

  def browser_server_available?
    socket = TCPSocket.new("127.0.0.1", 8080)
    socket.close
    true
  rescue StandardError
    false
  end

  def extract_url(details)
    details.to_s[/https?:\/\/\S+/]
  end
end