Rails.application.routes.draw do
  root "landing#index"
  #root 'urls#index'
  resources :urls, only: [:create, :show, :new] do
    get :stats, on: :member
    get :show_info, on: :member
  end

  get '/:short', to: 'urls#show_with_token', as: :short
  get '/:token/info', to: 'urls#stats', as: :info

  get 'landing/index'
  get 'home/index'
  resources :visits
  resources :urls
  resources :healthcheck, only: :index
end
