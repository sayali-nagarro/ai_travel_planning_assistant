class ConversationsController < ApplicationController
  def show
    @conversation = current_conversation
    @messages = @conversation.messages.includes(:conversation).chronological

    if params[:conversation_id].blank?
      redirect_to root_path(conversation_id: @conversation.id), status: :see_other and return
    end
  end

  def destroy
    conversation = Conversation.find_by(id: params[:conversation_id])
    conversation&.destroy!
    redirect_to root_path, notice: "Started a new conversation."
  end

  private

  def current_conversation
    return Conversation.find(params[:conversation_id]) if params[:conversation_id].present?

    Conversation.create!
  end
end
