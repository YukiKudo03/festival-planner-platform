Rails.application.routes.draw do
  resources :notification_settings, only: [:index, :edit, :update]
  resources :notifications, only: [:index, :show, :update, :destroy]
  devise_for :users
  root "home#index"

  # Admin routes (system_admin and admin only)
  get 'admin/dashboard', to: 'admin#dashboard'
  get 'admin/users', to: 'admin#users'
  get 'admin/monitoring', to: 'admin#monitoring'

  # Public festival routes (accessible to all, including non-logged users)
  get 'public_festivals', to: 'public_festivals#index'
  get 'public_festivals/:id', to: 'public_festivals#show', as: :public_festival

  # Regular festival management routes (authenticated users)
  resources :festivals do
    resources :tasks, except: [:index]
    resources :vendor_applications, except: [:index]
    # Gantt chart for festival-specific tasks
    get 'gantt', to: 'festivals#gantt', as: :gantt
  end

  resources :tasks, only: [:index] do
    collection do
      get 'gantt', to: 'tasks#gantt'
    end
  end
  
  resources :vendor_applications, only: [:index]

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
end
