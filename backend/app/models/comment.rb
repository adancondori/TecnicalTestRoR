# app/models/comment.rb
class Comment < ApplicationRecord
    belongs_to :feature
    validates :body, presence: true
end
  