class Api::V1::CommentSerializer < ActiveModel::Serializer
    attributes :id, :body, :created_at
end