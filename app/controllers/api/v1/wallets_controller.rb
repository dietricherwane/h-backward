class Api::V1::WalletsController < Api::V1::ApiController
  before_action :get_service_with_operation

  def load_required_fields
    @@wallets_required_filed ||= YAML::load_file(Rails.root.join("config", "api_wallets_required_fields.yml").to_s)
  end

  def get_fee(wallet)
    @service.fee || wallet.fee
  end

  def wallets_list
    wallets = Wallet.where(available_for_api: true)
    wallets_list = []
    wallets.each do |wallet|
      wallet.fee = get_fee(wallet)
      wallets_list << wallet.as_json
    end
    wallets_list.map! { |wallet| wallet.keep_if { |key, value| ["name", "alias", "fee"].include? key } }
    api_wallet_with_details = {
      wallets_list: wallets_list,
      fields: {}
    }

    required_fields = load_required_fields
    wallets.each do |wallet|
      wallet_alias = wallet.alias
      wallet_fields_info = required_fields[wallet_alias]
      api_wallet_with_details[:fields].merge! wallet_alias => wallet_fields_info
    end
    render json: api_wallet_with_details
  end
end
