class MessagesController < ApplicationController
  before_action :set_chat

  def create
    content = params.dig(:message, :content)
    attachments = params.dig(:message, :attachments)

    if content.present? || attachments.present?
      message = @chat.add_message(
        role: :user,
        content: content.to_s
      )

      if attachments.present?
        message.attachments.attach(attachments)
      end

      ChatResponseJob.perform_later(@chat.id, message.id)

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to @chat }
      end
    end
  end

  private

  def set_chat
    @chat = Chat.find(params[:chat_id])
  end
end