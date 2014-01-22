HubsBackOffice::Application.routes.draw do
  #root 'errors_handling#error_page'
  
  get "products/index"
  get "products/edit"
  get "products/show"
  get "products/testing_json_parsing"
  post "products/create"
  post "products/update"
  post "products/delete"
  
  get "paymoney/:service_id/:operation_id/:basket_number/:transaction_amount" => "pay_money#guard"
  get "PayMoney" => "pay_money#index"
  post "PayMoney/ProcessPayment" => "pay_money#process_payment"
  
  get "paypal/:service_id/:operation_id/:basket_number/:transaction_amount" => "paypal#guard"
  get "Paypal" => "paypal#index"
  get "Paypal/PaymentResult" => "paypal#paypal_display"
  post "Paypal/ProcessPayment" => "paypal#process_payment"
  get "Paypal/PaymentResultListener" => "paypal#payment_result_listener"
  
  get "PayPal/PaymentValidation" => "paypal_payment_validation#my_queue"
  
  get "error" => "errors_handling#error_page", as: :error_page
  get "success" => "errors_handling#success_page", as: :success_page
  
  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

  # You can have the root of your site routed with "root"
  # root 'welcome#index'
  #resources :products

  # Example of regular route:
  #   get 'products/:id' => 'catalog#view'

  # Example of named route that can be invoked with purchase_url(id: product.id)
  #   get 'products/:id/purchase' => 'catalog#purchase', as: :purchase

  # Example resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Example resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Example resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Example resource route with more complex sub-resources:
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', on: :collection
  #     end
  #   end
  
  # Example resource route with concerns:
  #   concern :toggleable do
  #     post 'toggle'
  #   end
  #   resources :posts, concerns: :toggleable
  #   resources :photos, concerns: :toggleable

  # Example resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end
end
