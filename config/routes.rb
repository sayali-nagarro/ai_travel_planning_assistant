Rails.application.routes.draw do
  root "conversations#show"

  resource :conversation, only: %i[show destroy] do
    resources :messages, only: :create
  end

  get "up" => "rails/health#show", as: :rails_health_check

  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
end
