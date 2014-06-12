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
        @message << "<div class='va-wrapper'>"
        @wallets.each do |wallet|
          @message << "<div class='va-slice' style = 'background:#000 url(#{wallet.logo}) no-repeat center center;'>
          <h3 class='va-title'>#{wallet.name}</h3>
          <div class='va-content'>
          <p>Description</p>
          <ul>
          <li><a href='#{wallet.url}/#{session[:service].code}/#{session[:operation].code}/#{@basket_number}/#{@transaction_amount}'>Payer: #{@transaction_amount} USD</a></li>
          </ul>
          </div>
          </div>
          "
        end
        @message << "</div>"
      end
    end
        
    render :text => @message.html_safe
  end
end
