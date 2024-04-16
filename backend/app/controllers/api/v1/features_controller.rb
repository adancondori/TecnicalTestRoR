# app/controllers/api/v1/features_controller.rb
class Api::V1::FeaturesController < ApplicationController
  def index
    features = Feature.all
    if params[:filters] && params[:filters][:mag_type].present?
      mag_types = params[:filters][:mag_type].split(',')
      features = features.where(mag_type: mag_types)
    end
    features = features.page(params[:page] || 1).per(params[:per_page] || 10)
    
    render json: {
      data: ActiveModel::Serializer::CollectionSerializer.new(
        features,
        serializer: Api::V1::FeatureSerializer,
        each_serializer: Api::V1::FeatureSerializer
      ),
      pagination: {
        current_page: features.current_page,
        total: features.total_count,
        per_page: features.limit_value
      }
    }
  end

  def show
    feature = Feature.find(params[:id])
    render json: feature, serializer: Api::V1::FeatureSerializer
  end
end
