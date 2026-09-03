class AgentController < ApplicationController
  def chat
    user_message = params[:message]

    if user_message.present?
      @message = ::SeraAi.call(user_message)
    end
  end
end