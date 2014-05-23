HubsBackOffice::Application.routes.draw do
  #root 'errors_handling#error_page'
  
  get "products/index"
  get "products/edit"
  get "products/show"
  get "products/testing_json_parsing"
  post "products/create"
  post "products/update"
  post "products/delete"
  
  get "paymoney/:service_id/:operation_id/:basket_number/:transaction_amount" => "pay_money#guard", :constraints => {:transaction_amount => /\-*\d+.\d+/}
  get "PayMoney" => "pay_money#index"
  post "PayMoney/ProcessPayment" => "pay_money#process_payment"
  get "PayMoney/Account" => "pay_money#account"
  post "PayMoney/CreateAccount" => "pay_money#create_account"
  get "PayMoney/CreditAccount" => "pay_money#credit_account"
  post "PayMoney/Account/AddCredit" => "pay_money#add_credit"
  post "paymoney/ipn" => "pay_money#ipn" 
  post "paymoney/transaction_acknowledgement" => "pay_money#transaction_acknowledgement"
  
  get "paypal/:service_id/:operation_id/:basket_number/:transaction_amount" => "paypal#guard", :constraints => {:transaction_amount => /\-*\d+.\d+/}
  get "Paypal" => "paypal#index"
  get "Paypal/PaymentResult" => "paypal#paypal_display"
  post "Paypal/ProcessPayment" => "paypal#process_payment"
  get "Paypal/PaymentResultListener" => "paypal#payment_result_listener"
  post "paypal/ipn" => "paypal#ipn" 
  post "paypal/transaction_acknowledgement" => "paypal#transaction_acknowledgement"
  
  get "PayPal/PaymentValidation" => "paypal_payment_validation#my_queue"
  
  get "delayed_payments/:service_id/:operation_id/:basket_number/:transaction_amount" => "delayed_payments#guard"
  get "Delayed_Payment" => "delayed_payments#index"
  get "delayed_payment_listener/:service_id/:operation_id/:basket_number/:transaction_amount" => "delayed_payments#delayed_payment_listener"
  #get "Delayed_Payment/PaymentResult" => "paypal#paypal_display"
  #post "Paypal/ProcessPayment" => "paypal#process_payment"
  #get "Paypal/PaymentResultListener" => "paypal#payment_result_listener"
  
  get "Wimboo/Reports/Operations" => "reports#wimboo_operations"
  post "Wimboo/FilterOperations" => "reports#filter_wimboo_operations"  
  get "Wimboo/Reports/AyantsDroit" => "reports#wimboo_ayants_droit"
  
  get "E-kiosk/Reports/Operations" => "reports#gepci_operations"
  post "E-kiosk/FilterOperations" => "reports#filter_gepci_operations"
  get "E-kiosk/Reports/AyantsDroit" => "reports#gepci_ayants_droit"
  
  get "error" => "errors_handling#error_page", as: :error_page
  get "success" => "errors_handling#success_page", as: :success_page
  
  get "services" => "services#index"
  get "service/create" => "services#create"
  get "service/update" => "services#update"
  get "service/disable" => "services#disable"
  get "service/enable" => "services#enable"
  
  get "operation/create" => "operations#create"
  get "operation/update" => "operations#update"
  get "operation/disable" => "operations#disable"
  get "operation/enable" => "operations#enable"
  
  get "payment_way_fee/create" => "payment_way_fees#create"
  get "payment_way_fee/update" => "payment_way_fees#update"
  
  
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
