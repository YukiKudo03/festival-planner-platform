class ReactionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_reactable

  def create
    @reaction = @reactable.reactions.find_or_initialize_by(user: current_user)

    if @reaction.persisted? && @reaction.reaction_type == reaction_params[:reaction_type]
      # Same reaction - remove it
      @reaction.destroy
      @reaction = nil
    else
      # New reaction or different reaction - update it
      @reaction.reaction_type = reaction_params[:reaction_type]
      @reaction.save!
    end

    respond_to do |format|
      format.json {
        render json: {
          success: true,
          reaction_summary: @reactable.reaction_summary,
          user_reaction: @reactable.user_reaction(current_user)
        }
      }
      format.html { redirect_back(fallback_location: root_path) }
    end
  end

  def update
    create # Same logic as create
  end

  def destroy
    @reaction = @reactable.reactions.find_by(user: current_user)
    @reaction&.destroy

    respond_to do |format|
      format.json {
        render json: {
          success: true,
          reaction_summary: @reactable.reaction_summary,
          user_reaction: nil
        }
      }
      format.html { redirect_back(fallback_location: root_path) }
    end
  end

  private

  def set_reactable
    reactable_type = params[:reactable_type]
    reactable_id = params[:reactable_id]

    case reactable_type
    when "ForumThread"
      @reactable = ForumThread.find(reactable_id)
    when "ForumPost"
      @reactable = ForumPost.find(reactable_id)
    when "ChatMessage"
      @reactable = ChatMessage.find(reactable_id)
    else
      render json: { error: "Invalid reactable type" }, status: :unprocessable_entity
      nil
    end
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Reactable not found" }, status: :not_found
  end

  def reaction_params
    params.require(:reaction).permit(:reaction_type)
  end
end
