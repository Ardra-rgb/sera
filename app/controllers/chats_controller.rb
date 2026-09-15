class ChatsController < ApplicationController
  before_action :set_chat, only: [:show, :destroy]

  def index
    @chats = filtered_chats
  end

  def new
    @chat = Chat.new
    @selected_model = params[:model]
    @chat_models = available_chat_models
    @chats = filtered_chats
  end

  def create
    prompt = params.dig(:chat, :prompt)
    attachments = params.dig(:chat, :attachments)

    if prompt.present? || attachments.present?
      model = params.dig(:chat, :model).presence
      provider = params.dig(:chat, :provider).presence

      ruby_llm_provider =
        provider == "groq" ? :openai : :gemini

      @chat = Chat.new

      @chat.with_model(
        model,
        provider: ruby_llm_provider,
        assume_exists: provider == "groq"
      )

      message = @chat.messages.create!(
        role: :user,
        content: prompt.to_s
      )

      if attachments.present?
        message.attachments.attach(attachments)
      end

      ChatResponseJob.perform_later(@chat.id, message.id)

      redirect_to @chat, notice: "Chat was successfully created."
    end
  end
  def show
    @message = @chat.messages.build
    @chats = filtered_chats
  end

  def destroy
    @chat.destroy!
    redirect_to chats_path, notice: "Chat was successfully destroyed.", status: :see_other
  end

  private

  def filtered_chats
    if params[:q].present?
      Chat.joins(:messages)
          .where("messages.content LIKE ?", "%#{params[:q]}%")
          .distinct
          .order(created_at: :desc)
    else
      Chat.order(created_at: :desc)
    end
  end

  def set_chat
    @chat = Chat.find(params[:id])
  end
end