module Api
    module V1
      class BaseController < ApplicationController
        protect_from_forgery with: :null_session
  
        rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
        rescue_from ActiveRecord::RecordInvalid, with: :record_invalid
  
        private
  
        # Manejador de error cuando un registro no se encuentra
        def record_not_found(error)
          render json: { error: error.message }, status: :not_found
        end
  
        # Manejador de error cuando un registro es inválido
        def record_invalid(error)
          render json: { errors: error.record.errors.full_messages }, status: :unprocessable_entity
        end
  
        # Métodos adicionales para autenticación y otros procesos comunes podrían ser añadidos aquí
      end
    end
end
  