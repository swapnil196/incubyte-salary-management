Rails.application.routes.draw do
  # Returns 200 once the app boots cleanly. Used by the platform health check.
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      resources :employees, only: %i[index show]
    end
  end

  root "app#index"

  # SPA fallback. Anything that is not an API call, an asset or the health check
  # renders the React shell, so deep links and reloads work.
  get "*path", to: "app#index", format: false,
      constraints: ->(request) { !request.path.start_with?("/api", "/vite", "/up") }
end
