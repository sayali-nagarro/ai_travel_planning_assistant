class MessagesController < ApplicationController
  skip_forgery_protection only: :create

  def create
    @conversation = current_conversation
    @result = Travel::Assistant.call(conversation: @conversation, user_message: message_params[:content])

    respond_to do |format|
      format.html do
        redirect_to root_path(conversation_id: @conversation.id)
      end

      format.turbo_stream

      format.json do
        render json: @result.as_json, status: :created
      end
    end
  end

  private

  def message_params
    params.require(:message).permit(:content)
  end

  def current_conversation
    conversation_id = params[:conversation_id].presence || message_params[:conversation_id].presence
    return Conversation.find(conversation_id) if conversation_id

    Conversation.create!
  end
end
