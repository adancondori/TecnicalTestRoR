class ApplicationController < ActionController::Base
    rescue_from ActiveRecord::RecordNotFound, with: :record_not_found

    private

    def record_not_found
        respond_to do |format|
        format.html { redirect_to root_url, alert: "La URL solicitada no fue encontrada." }
        format.json { render json: { error: "Record not found" }, status: 404 }
        end
    end
end
