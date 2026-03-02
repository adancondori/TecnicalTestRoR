Rails.application.routes.draw do
  mount Rswag::Ui::Engine => "/api-docs"
  mount Rswag::Api::Engine => "/api-docs"

  root "landing#index"

  # Merchants CRUD + nested dashboard
  resources :merchants do
    member do
      patch :regenerate_webhook_secret
    end
    scope module: :merchants do
      resources :payment_requests, only: [:show] do
        member do
          post :capture
          post :void
        end
        resources :refunds, only: [:create]
      end
    end
  end

  namespace :api do
    namespace :v1 do
      resources :payment_methods, only: [:create, :index, :show]
      resources :payment_requests, only: [:create, :index, :show] do
        member do
          post :capture
          post :void
        end
        resources :refunds, only: [:create]
      end
      resources :refunds, only: [:index, :show]
      post "qr_payments/:id/simulate", to: "qr_payments#simulate"
    end
  end

  # 3DS Challenge (server-rendered)
  get "3ds/challenge/:id", to: "three_d_secure#challenge", as: :three_d_secure_challenge
  post "3ds/challenge/:id/verify", to: "three_d_secure#verify", as: :three_d_secure_verify

  # eWallet Simulation (server-rendered)
  get "ewallet/pay/:id", to: "ewallet_simulation#pay", as: :ewallet_pay
  post "ewallet/pay/:id/confirm", to: "ewallet_simulation#confirm", as: :ewallet_confirm
end
