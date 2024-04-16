class Api::V1::CommentsController < ApplicationController
  protect_from_forgery with: :null_session

  def create
    feature = Feature.find(params[:feature_id])
    comment = feature.comments.build(comment_params)
    if comment.save
      render json: comment, status: :created
    else
      render json: comment.errors, status: :unprocessable_entity
    end
  end

  private
  def comment_params
    params.require(:comment).permit(:body)
  end
end
  