HubsBackOffice::Application.routes.draw do
  root 'errors_handling#home_page'

  get "order/:currency/:service_token/:operation_token/:order/:transaction_amount/:id" => "main#guard", :constraints => {:transaction_amount => /(\d+(.\d+)?)/}
  get "order/:currency/:service_token/:operation_token/:order/:transaction_amount" => "main#guard", :constraints => {:transaction_amount => /(\d+(.\d+)?)/}
  get "order/:currency/:service_token/:operation_token/:order/:transaction_amount" => "main#guard", :constraints => {:transaction_amount => /(\d+(.\d+)?)/}
  get "/order/unload/:currency/:service_token/:operation_token/:order/:transaction_amount/:paymoney_account_number" => "main#guard", :constraints => {:transaction_amount => /(\d+(.\d+)?)/}
  get "/Main" => "main#index", as: :main

  get "get_wallets" => "wallets#get_wallets"

  get "duke" => "mtn_cis#duke"

  # Upload wallets logos
  get "bfaad58e15f671064fd87277/wallets/edit/:authentication_token" => "wallets#edit"
  post "bfaad58e15f671064fd87277/wallets/update/:authentication_token" => "wallets#update", as: :update_wallet
  post "wallets/available" => "wallets#available"
  post "available_wallet/enable_disable" => "available_wallets#enable_disable"
  post "wallets/used_per_country/:token" => "wallets#used_wallets_per_country"
  post "wallet/successful_transactions/:service_token/:wallet_token" => "wallets#successful_transactions_per_service"
  post "wallet/failed_transactions/:service_token/:wallet_token" => "wallets#failed_transactions_per_service"

  get "paymoney/:service_id/:operation_id/:basket_number/:transaction_amount" => "pay_money#guard", :constraints => {:transaction_amount => /(\d+(.\d+)?)/}
  get "PayMoney" => "pay_money#index"
  post "PayMoney/ProcessPayment" => "pay_money#process_payment"
  get "PayMoney/Account" => "pay_money#account"
  post "PayMoney/CreateAccount" => "pay_money#create_account"
  get "PayMoney/CreditAccount" => "pay_money#credit_account"
  post "PayMoney/Account/AddCredit" => "pay_money#add_credit"
  post "paymoney/ipn" => "pay_money#ipn"
  post "paymoney/transaction_acknowledgement" => "pay_money#transaction_acknowledgement"
  post "paymoney/transaction_acknowledgement/:transaction_id" => "pay_money#transaction_acknowledgement"
  get "paymoney/transaction_acknowledgement/:transaction_id" => "pay_money#transaction_acknowledgement"

  get "paypal/:service_id/:operation_id/:basket_number/:transaction_amount" => "paypal#guard", :constraints => {:transaction_amount => /(\d+(.\d+)?)/}
  get "Paypal" => "paypal#index"
  get "Paypal/PaymentResult" => "paypal#paypal_display"
  post "Paypal/ProcessPayment" => "paypal#process_payment"
  get "Paypal/PaymentResultListener" => "paypal#payment_result_listener"
  post "paypal/ipn" => "paypal#ipn"
  post "Paypal/transaction_acknowledgement" => "paypal#transaction_acknowledgement"
  get "Paypal/transaction_acknowledgement/:transaction_id" => "paypal#transaction_acknowledgement"
  post "Paypal/transaction_acknowledgement/:transaction_id" => "paypal#transaction_acknowledgement"

  get "orange_money_ci/:service_id/:operation_id/:basket_number/:transaction_amount" => "orange_money_ci#guard", :constraints => {:transaction_amount => /(\d+(.\d+)?)/}
  get "OrangeMoneyCI" => "orange_money_ci#index"
  post "/OrangeMoneyCI/ProcessPayment" => "orange_money_ci#redirect_to_billing_platform"
  post "OrangeMoneyCI/PaymentResultListener" => "orange_money_ci#payment_result_listener"
  post "OrangeMoneyCI/ipn" => "orange_money_ci#ipn"
  get "om" => "orange_money_ci#initialize_session"
  post "OrangeMoneyCI/transaction_acknowledgement" => "orange_money_ci#transaction_acknowledgement"
  post "OrangeMoneyCI/transaction_acknowledgement/:transaction_id" => "orange_money_ci#transaction_acknowledgement"
  get "OrangeMoneyCI/transaction_acknowledgement/:transaction_id" => "orange_money_ci#transaction_acknowledgement"

  get "mtn_ci/:service_id/:operation_id/:basket_number/:transaction_amount" => "mtn_cis#guard", :constraints => {:transaction_amount => /(\d+(.\d+)?)/}
  get "MTNCI" => "mtn_cis#index"
  post "/MTNCI/InitializePayment" => "mtn_cis#initialize_payment"
  post "/MTNCI/ProcessPayment" => "mtn_cis#redirect_to_billing_platform"
  post "MTNCI/PaymentResultListener" => "mtn_cis#payment_result_listener"
  post "MTNCI/ipn" => "mtn_cis#ipn"
  get "MTNCI/waiting_validation" => "mtn_cis#waiting_validation", as: :waiting_validation
  get "MTNCI/check_transaction_validation" => "mtn_cis#check_transaction_validation"
  get "MTNCI/redirect_to_merchant_website" => "mtn_cis#redirect_to_merchant_website"
  get "om" => "mtn_cis#initialize_session"
  post "MTNCI/transaction_acknowledgement" => "mtn_cis#transaction_acknowledgement"
  post "MTNCI/transaction_acknowledgement/:transaction_id" => "mtn_cis#transaction_acknowledgement"
  get "MTNCI/transaction_acknowledgement/:transaction_id" => "mtn_cis#transaction_acknowledgement"
  post "/api/93c080fe2b/MTNCI/confirm_amount/:reference_invoice/:transaction_id/:transaction_amount" => "mtn_cis#api_confirm_amount"

  post "/STAS/transaction/confirm" => "mtn_cis#payment_result_listener"

  get "/uba/:service_id/:operation_id/:basket_number/:transaction_amount" => "uba#guard", :constraints => {:transaction_amount => /(\d+(.\d+)?)/}
  get "/UBA" => "uba#index"
  post "/UBA/validate" => "uba#validate_transaction"
  post "/UBA/transaction_acknowledgement" => "uba#transaction_acknowledgement"
  get "/UBA/transaction_acknowledgement" => "uba#transaction_acknowledgement"


  get "novapay/:service_id/:operation_id/:basket_number/:transaction_amount" => "novapays#guard", :constraints => {:transaction_amount => /(\d+(.\d+)?)/}
  get "NovaPay" => "novapays#index"
  post "novapay/process_payment" => "novapays#process_payment"
  get "/NovaPay/script" => "novapays#payment_result_listener"
  post "/NovaPay/ipn" => "novapays#payment_result_listener"
  post "NovaPay/transaction_acknowledgement" => "novapays#transaction_acknowledgement"
  post "NovaPay/transaction_acknowledgement/:transaction_id" => "novapays#transaction_acknowledgement"
  get "NovaPay/transaction_acknowledgement/:transaction_id" => "novapays#transaction_acknowledgement"

  get "qash/:service_id/:operation_id/:basket_number/:transaction_amount" => "qash_baskets#guard", :constraints => {:transaction_amount => /(\d+(.\d+)?)/}
  get "Qash" => "qash_baskets#index"
  get "/Qash/PaymentResultListener" => "qash_baskets#payment_result_listener"
  #get "PayPal/PaymentValidation" => "paypal_payment_validation#my_queue"
  post "Qash/transaction_acknowledgement" => "qash_baskets#transaction_acknowledgement"
  post "Qash/transaction_acknowledgement/:transaction_id" => "qash_baskets#transaction_acknowledgement"
  get "Qash/transaction_acknowledgement/:transaction_id" => "qash_baskets#transaction_acknowledgement"

  get "delayed_payments/:service_id/:operation_id/:basket_number/:transaction_amount" => "delayed_payments#guard"
  get "Delayed_Payment" => "delayed_payments#index"
  get "delayed_payment_listener/:service_id/:operation_id/:basket_number/:transaction_amount" => "delayed_payments#delayed_payment_listener"
  #get "Delayed_Payment/PaymentResult" => "paypal#paypal_display"
  #post "Paypal/ProcessPayment" => "paypal#process_payment"
  #get "Paypal/PaymentResultListener" => "paypal#payment_result_listener"

  get "flooz" => "moov_flooz_ci#index"

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
  post "service/qualify" => "services#qualify"
  post "service/enable_disable" => "services#enable_disable"

  get "operation/create" => "operations#create"
  get "operation/update" => "operations#update"
  get "operation/disable" => "operations#disable"
  get "operation/enable" => "operations#enable"

  get "payment_way_fee/create" => "payment_way_fees#create"
  get "payment_way_fee/update" => "payment_way_fees#update"

  get 'guce' => 'products#guce'

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
  get '*rogue_url', :to => 'errors#routing'
  post '*rogue_url', :to => 'errors#routing'
end
