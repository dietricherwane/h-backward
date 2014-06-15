class WalletsController < ApplicationController
  def get_wallets
    @message = ""
    @country = Country.where("id = #{params[:country_id]} AND published IS TRUE")
    if @country.blank?
      @message = "Ce pays n'existe pas."
    else
      @wallets = Wallet.where("country_id = #{@country.first.id} AND published IS NOT FALSE")
      if @wallets.blank?
        @message = "Il n'y a aucun moyen de paiement pour ce pays."
      else
        @transaction_amount = session[:basket]["transaction_amount"]
        @basket_number = session[:basket]['basket_number']
        @wallets.each do |wallet|
          @url = "#{wallet.url}/#{session[:service].code}/#{session[:operation].code}/#{session[:basket]['basket_number']}/#{session[:basket]['transaction_amount']}"
          @message << "<a href='#{@url}'>
          <span data-hover='#{wallet.name}'>
          #{wallet.name}
          </span>
          </a>
          "
        end
      end
    end
        
    render :text => @message.html_safe
  end
end
