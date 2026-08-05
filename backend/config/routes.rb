Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Cockpit staff (ward_nurse/nurse/physician/site_admin/sysadmin/analyst)
  # session auth. :passwords (recoverable) route is deliberately deferred —
  # no forgot-password UI exists yet; the model module stays loaded so
  # adding the route later is a routes.rb + controller change only.
  devise_for :users, path: "api/v1/staff", skip: [ :passwords ],
    controllers: { sessions: "api/v1/staff/sessions" }

  mount ActionCable.server => "/cable"

  namespace :api do
    namespace :v1 do
      get "health" => "health#show"
      get "feature_flags" => "feature_flags#show"

      namespace :staff do
        get "me" => "me#show"
        resources :drugs, only: [ :index ]
        resources :enrollments, only: [ :create ]
        get "enrollments/:episode_id/code_sheet" => "enrollments#code_sheet"

        resources :flags, only: [ :index, :show, :create, :update ] do
          collection { get :summary }
          member { get :triage_draft; get :callnote_draft; get :ai_watch_rationale }
        end

        resources :patients, only: [ :index, :show ]

        resources :episodes, only: [] do
          resource :care_plan, only: [ :create ]
          resources :messages, only: [ :index, :create ] do
            collection { post :preview }
          end
          resource :assistant_conversation, only: [ :show ]
          resource :report, only: [ :show ]
          member { post :graduate }
          # UC-24: post-promotion cadence-adaptation proposals.
          resources :cadence_proposals, only: [ :index ] do
            member { post :approve; post :dismiss }
          end
        end

        resources :knowledge_docs, only: [ :index, :show, :create, :update ] do
          member { post :approve }
        end

        resources :content_items, only: [ :index, :show, :create, :update ] do
          member { post :approve }
        end

        get "analytics/pilot_metrics" => "analytics#pilot_metrics"

        # UC-21: MD/ADM-gated shadow-model promotion, per site.
        resources :sites, only: [] do
          resource :risk_model, only: [ :show ], controller: "risk_model" do
            post :promote
          end
        end
      end

      resources :sites, only: [ :index, :show, :create, :update ]

      namespace :caregiver do
        resources :activations, only: [ :create ]
        resource :onboarding, only: [ :update ]
        resources :check_ins, only: [ :create, :update ] do
          resources :photos, only: [ :create ], controller: "check_in_photos"
        end
        resource :push_subscription, only: [ :update ]
        resources :notification_attempts, only: [] do
          member { post :confirm }
        end
        resources :messages, only: [ :index, :create ]
        resources :assistant_messages, only: [ :index, :create ] do
          member { post :escalate }
        end
        get "home" => "home#show"
        post "care_plan/explain" => "care_plan_explanations#create"
        get "trends" => "trends#show"
        get "care_team" => "care_team#show"
        resources :medication_doses, only: [ :index, :create ]
        resources :content_items, only: [ :index ] do
          member { post :complete }
        end
      end
    end
  end

  # Defines the root path route ("/")
  # root "posts#index"
end
