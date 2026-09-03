require "pdf-reader"

class ChatResponseJob < ApplicationJob
  def perform(chat_id, message_id)
    chat = Chat.find(chat_id)
    user_message = chat.messages.find(message_id)
    return unless user_message

    process_attachments(user_message)

    llm_chat = chat.to_llm

    browser_request = user_message.content.to_s.match?(
      /\b(download|install|browse|website|webpage|search the web|online|continue|resume)\b/i
    )

    if browser_request
      llm_chat.with_tools(
        BrowserApplicationTool,
        choice: :required,
        calls: :one
      )
    else
      llm_chat.with_tools(
        SearchDocumentsTool,
        ApplicationAssistantTool,
        BrowserApplicationTool
      )
    end

    llm_chat.with_instructions(<<~PROMPT)
      You are SERA, an autonomous assistant that can use tools.

      TOOL SELECTION RULES:

      1. For questions about information already stored in the user's
         documents, use SearchDocumentsTool.

      2. For application-related tasks, use ApplicationAssistantTool
         to manage the application workflow.

      3. For requests that require interacting with a website, searching
         the web, opening websites, clicking links, navigating pages,
         downloading files, or interacting with online forms, use
         BrowserApplicationTool.

      4. When the user asks you to download software such as a browser,
         use BrowserApplicationTool to find the official website and
         perform the download.

      5. When asked to download software, prefer the official vendor
         website and verify the domain before downloading.

      6. Never claim that you completed a browser action unless the
         BrowserApplicationTool actually reports that the action succeeded.

      7. If a website requires CAPTCHA, OTP, payment authorization,
         biometric verification, identity verification, anti-bot checks,
         or another protected human-only step, do not bypass it.
         Use the human_help action and wait for the user.

      8. Never submit an application or make a purchase without explicit
         user approval.

      9. Do not answer a browser-action request with "the information is
         not available in the documents." Use the appropriate browser tool
         instead.

      10. For software downloads, do not execute or install the downloaded
          program unless the user explicitly approves that separate action.

      11. After a browser action, use the tool result to decide the next
          appropriate step. Do not invent URLs, downloaded files, or
          successful actions.

      12. If the user says "continue", "resume", or confirms that they
          completed a human verification step, use BrowserApplicationTool
          with the continue action to inspect the current visible browser
          page and resume the task.
    PROMPT

    response = llm_chat.ask(user_message.content.to_s)

    assistant_message = chat.messages.where(role: :assistant).last
    assistant_message.update!(content: response.content)
    assistant_message.broadcast_append_chunk(response.content)
  end

  private

  def process_attachments(message)
    return unless message.attachments.attached?

    message.attachments.each do |attachment|
      blob = attachment.blob

      extracted_text =
        if blob.content_type == "application/pdf"
          PDF::Reader
            .new(StringIO.new(blob.download))
            .pages
            .map(&:text)
            .join("\n\n")

        elsif blob.content_type.start_with?("image/")
          response = RubyLLM.chat(model: "gemini-3.5-flash").ask(
            "Extract all useful factual information from this image. " \
            "Return only the information as plain text that could be " \
            "searched later. Preserve names, numbers, dates, IDs, amounts, " \
            "and other important details.",
            with: attachment
          )

          response.content

        else
          next
        end

      next if extracted_text.blank?

      document = Document.create!(
        filename: blob.filename.to_s,
        content: extracted_text
      )

      chunks = extracted_text
        .split(/\n{2,}/)
        .map(&:strip)
        .reject(&:empty?)

      chunks.each do |chunk_text|
        vector = RubyLLM.embed(
          chunk_text,
          model: "gemini-embedding-001",
          provider: :gemini,
          assume_model_exists: true
        ).vectors

        document.document_chunks.create!(
          content: chunk_text,
          embedding: vector.to_json
        )
      end
    end
  end
end