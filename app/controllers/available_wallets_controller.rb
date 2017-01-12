class AvailableWalletsController < ApplicationController

  # Enables or disables a wallet for a given service
  def enable_disable
    @service = Service.find(token: params[:service_token])
    @wallet = Wallet.find(authentication_token: params[:wallet_token])

    if @service && @wallet
      available_wallet = AvailableWallet.where(service_id: @service.id, wallet_id: @wallet.id)
      if available_wallet.empty?
        render json: {"status" => "1"}
      else
        available_wallet.first.update_attribute(:published, (params[:status] == "true" ? true : false))
        render json: {"status" => "2"}
      end
    else
      render json: {"status" => "0"}
    end
  end

end
