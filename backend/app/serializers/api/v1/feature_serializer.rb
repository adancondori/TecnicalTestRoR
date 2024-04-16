# app/serializers/api/v1/feature_serializer.rb
class Api::V1::FeatureSerializer < ActiveModel::Serializer
  attributes :id, :title, :place, :magnitude, :mag_type, :time, :tsunami, :coordinates, :external_url

  has_many :comments

  def coordinates
    { longitude: object.longitude, latitude: object.latitude }
  end

  def time
    object.created_at.strftime("%Y-%m-%d %H:%M:%S")
  end

  def mag_type
    object.mag_type
  end

  def external_url
    object.external_url
  end
end
