class WalletsController < ApplicationController
  def get_wallets
    @message = ""
    @country = Country.where("id = #{params[:country_id]} AND published IS TRUE")
    if @country.blank?
      @message = "Ce pays n'existe pas."
    else
      @available_wallets = session[:service].available_wallets.where(
        published: true, 
        wallet_id: session[:service].wallets.where(country_id: @country.first.id).map{|w| w.id}
      )
      if @available_wallets.blank?
        @message = "Il n'y a aucun moyen de paiement pour ce pays."
      else
        @transaction_amount = session[:basket]["transaction_amount"]
        @basket_number = session[:basket]['basket_number']
        @available_wallets.each do |available_wallet|
          wallet_name = available_wallet.wallet.name.split.first.downcase
          @url = "#{available_wallet.wallet.url}/#{session[:service].code}/#{session[:operation].code}/#{session[:basket]['basket_number']}/#{session[:basket]['transaction_amount']}"
          @message << "<a href='#{@url}' class='#{wallet_name} wallet_link'>
          <img src = '#{available_wallet.wallet.logo.url(:medium)}' />
          </a>"
        end
      end
    end

    render text: @message.html_safe
  end

  def edit
    @wallet = Wallet.find_by_authentication_token(params[:authentication_token])
    render file: "#{Rails.root}/public/404.html", status: 404, layout: false unless @wallet
  end

  def update
    @wallet = Wallet.find(authentication_token: params[:authentication_token])
    render file: "#{Rails.root}/public/404.html", status: 404, layout: false unless @wallet
    @wallet.update_attributes(params[:wallet])
    flash.now[:notice] = "Le logo du wallet a été ajouté"

    render :edit
  end

  # Returns the list of available wallets per countries as JSON objects
  def available
    my_hash = {}

    countries = Country.where(published: true).as_json
    countries.each do |country|
      country_object = Country.find_by_id(country["id"])
      wallets = country_object.wallets.where(published: true)
      my_wallets = format_wallets(wallets)
      my_hash.merge!("#{country['id']}" => country.merge({wallets: my_wallets}))
    end

    render json: my_hash
  end

  def format_wallets(wallets)
    my_wallets = []

    unless wallets.empty?
      wallets.each do |wallet|
        my_wallets << wallet.as_json.merge({currency: wallet.currency.name, logo: "#{ENV['back_office_url']}#{wallet.logo.url(:medium)}"}).except(*["id", "created_at", "updated_at", "country_id", "published", "logo_file_name", "logo_content_type", "logo_file_size", "logo_updated_at", "url", "currency_id", "percentage"])
      end
    end

    return my_wallets
  end

  def format_used_wallets(available_wallets)
    my_wallets = []

    unless available_wallets.empty?
      available_wallets.each do |available_wallet|
        wallet = available_wallet.wallet
        my_wallets << wallet.as_json.merge({currency: wallet.currency.name, logo: "#{ENV['back_office_url']}#{wallet.logo.url(:medium)}", succeed_transactions: available_wallet.succeed_transactions.to_i, failed_transactions: available_wallet.failed_transactions.to_i}).except(*["id", "created_at", "updated_at", "country_id", "published", "logo_file_name", "logo_content_type", "logo_file_size", "logo_updated_at", "url", "currency_id", "percentage"])
      end
    end

    return my_wallets
  end

  # Used to display on the front the list of wallets per country having transactions
  def used_wallets_per_country
    @service = Service.find_by_token(params[:token])
    available_wallets = @service.available_wallets.where(wallet_used: true) rescue nil
    my_hash = {}

    if available_wallets
      available_countries = available_wallets.map{|w| w.wallet.country.id}
      countries = Country.where(id: available_countries)

      countries.each do |country|
        @available_wallets = AvailableWallet.where(service_id: @service.id, wallet_id: country.wallets.map{|w| w.id}, wallet_used: true)#.map{|aw| aw.wallet}

        my_wallets = format_used_wallets(@available_wallets)
        my_hash.merge!("#{country.id}" => country.as_json.merge({wallets: my_wallets}))
      end

    end
    render json: my_hash
  end

  def successful_transactions_per_service
    generic_transactions_per_service(params[:service_token], params[:wallet_token], true)
  end

  def failed_transactions_per_service
    generic_transactions_per_service(params[:service_token], params[:wallet_token], false)
  end

  def generic_transactions_per_service(service_token, wallet_token, successful)
    @service = Service.find_by_token(service_token)
    wallet = Wallet.find_by_authentication_token(wallet_token)
    transactions = {}
    my_transactions = ""

    if @service && wallet
      # To get successful transactions
      if successful
        transactions = @service.send(wallet.table_name).where(payment_status: true).order("created_at DESC").as_json rescue {}
      # To get failed transactions
      else
        transactions = @service.send(wallet.table_name).where("payment_status IS FALSE").order("created_at DESC").as_json rescue {}
      end
    end

    transactions.each do |transaction|
      wallet_currency = Currency.find_by_id(transaction['paid_currency_id'])
      my_transactions << transaction.merge!({full_transaction_amount: "#{transaction['transaction_amount']} #{(Currency.find_by_id(transaction['currency_id']).symbol rescue nil)}", full_fee: "#{transaction['fees']} #{(wallet_currency.symbol rescue nil)}", full_paid_transaction_amount: "#{transaction['paid_transaction_amount']} #{(wallet_currency.symbol rescue nil)}"}).to_json << ","
    end
    my_transactions.chop!
    my_transactions =  "[" + my_transactions + "]"

    render json: my_transactions
  end
end
