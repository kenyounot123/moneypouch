Rails.application.routes.draw do
  namespace :transactions do
    resource :download, only: :show
  end
  resources :transactions, only: %i[ index create edit destroy ] do
    resource :categorization, only: :update, module: :transactions
    resource :rule, only: :create, module: :transactions
    resource :note, only: :update, module: :transactions
    resource :exclusion, only: :update, module: :transactions
  end
  resource :voucher, only: :show
  resource :session, only: %i[ new create destroy ]
  resource :settings, only: :show
  resource :seen_release, only: :create
  resource :account, only: %i[ new create ]
  resource :first_transaction, controller: "first_transaction", only: :show

  namespace :simplefin do
    resource :access, only: %i[ new create edit update destroy ]
    resource :sync, only: :create
    resource :review, only: %i[ show update ]
  end
  resources :bank_accounts, only: :update
  resources :rules, only: :destroy
  resources :imports, only: %i[ new create destroy ] do
    scope module: :imports do
      resource :columns, only: %i[ edit update ]
      resource :categories, only: %i[ edit update ]
      resource :transactions, only: :create
    end
  end
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  resource :theme, only: :update

  root "welcome#index"
end
