Rails.application.routes.draw do
  resources :transactions, only: %i[ index create update destroy ] do
    resource :categorization, only: :update, module: :transactions
    resource :rule, only: :create, module: :transactions
    resource :note, only: :update, module: :transactions
  end
  resource :voucher, only: :show
  resource :session
  resource :settings, only: :show
  resource :account, only: %i[ new create ]
  resource :first_transaction, controller: "first_transaction", only: :show

  namespace :simplefin do
    resource :access, only: %i[ new create edit update destroy ]
    resource :sync, only: :create
    resource :review, only: %i[ show update ]
  end
  resources :bank_accounts, only: :update do
    resources :rules, only: :destroy, module: :bank_accounts
  end
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  resource :dark_theme, controller: "dark_theme", only: :update
  resource :light_theme, controller: "light_theme", only: :update

  root "welcome#index"
end
