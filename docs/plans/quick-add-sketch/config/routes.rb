Rails.application.routes.draw do
  # P2 -> P9
  resources :transactions, only: %i[ index create update destroy ] do
    resource :restoration, only: :create, module: :transactions        # P9
  end

  resource :draft, only: :show                                         # P5, GET /draft?line=
  resources :completions, only: :index                                 # P8

  resource :session
  get "up" => "rails/health#show", as: :rails_health_check
  resource :dark_theme, controller: "dark_theme", only: :update
  resource :light_theme, controller: "light_theme", only: :update

  root "welcome#index"
end
