Rails.application.routes.draw do
  # フォーラム機能
  resources :festivals do
    resources :forums, except: [:index] do
      resources :forum_threads, except: [:index] do
        member do
          patch :pin
          patch :lock
        end
        resources :forum_posts, except: [:index, :show]
      end
    end
    
    # チャット機能
    resources :chat_rooms do
      resources :chat_messages, only: [:create, :edit, :update, :destroy]
      member do
        post :join
        delete :leave
        patch :mark_as_read
      end
    end
  end
  
  # 全体フォーラム一覧
  get 'forums', to: 'forums#index'
  
  # 全体チャット一覧
  get 'chat', to: 'chat_rooms#index'
  
  # ダイレクトメッセージ
  get 'messages/:user_id', to: 'chat_rooms#direct_message', as: :direct_message
  
  # リアクション機能
  resources :reactions, only: [:create, :update, :destroy]
  namespace :admin do
    resources :vendor_applications, only: [:index, :show, :update] do
      member do
        get :review
        patch :approve
        patch :reject
        patch :request_changes
        patch :conditionally_approve
        patch :start_review
      end
      
      collection do
        get :pending
        get :under_review
        get :overdue
        get :reports
        get :export_csv
        patch :bulk_approve
        patch :bulk_reject
      end
    end
  end
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
