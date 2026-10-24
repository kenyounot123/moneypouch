Rails.application.routes.draw do
  namespace :transactions do
    resource :download, only: :show
  end
  resources :transactions, only: %i[ index create edit destroy ] do
    resource :categorization, only: :update, module: :transactions
    resource :rule, only: :create, module: :transactions
    resource :note, only: :update, module: :transactions
    resource :exclusion, only: %i[ create destroy ], module: :transactions
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
    resource :review, only: :show do
      resource :completion, only: :create, module: :reviews
    end
  end
  resources :bank_accounts, only: :update
  resources :rules, only: :destroy
  resources :categories, only: %i[ index show update destroy ] do
    resource :merge, only: :create, module: :categories
  end
  resources :imports, only: %i[ new create destroy ] do
    scope module: :imports do
      resource :columns, only: %i[ edit update ]
      resource :categories, only: %i[ edit update ]
      resource :transactions, only: :create
    end
  end
  resource :mode, only: :update
  resource :theme, only: :update
  resource :time_zone, only: :update

  get "up" => "rails/health#show", as: :rails_health_check

  root "welcome#index"
end
