Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html

  devise_for :users, controllers: { sessions: 'users/sessions', registrations: 'users/registrations' }
  resource :track_files, only: [] do
    put :update_current, on: :member
    get :show_current, on: :member
  end

  root to: 'pages#index'
end
