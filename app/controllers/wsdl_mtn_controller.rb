class WsdlMtnController < ApplicationController

  soap_service namespace: 'PayMoney:MTN:wsdl'

  # GetBill
  soap_action "GetBill",
              :args   => { :Reference => :string },
              :return => :xml
  def GetBill
    bill = MtnCi.find_by_transaction_id(params[:Reference])

    if bill
      #if (bill.paid_transaction_amount + bill.fees).to_i == params[:Montant].to_i
        result = %Q[
            <?xml version="1.0" encoding="utf-8"?>
            <ArrayOfFacture>
              <Facture>
                <CODE>#{bill.transaction_id}</CODE>
                <NUMCLIENT>#{bill.process_online_client_number}</NUMCLIENT>
                <NUMFACTURE>#{bill.transaction_id}</NUMFACTURE>
                <DATEFACTURE>#{bill.created_at}</DATEFACTURE>
                <DELAIPAIEMENT>#{bill.created_at + 1.hour}</DELAIPAIEMENT>
                <MONTANT>#{(bill.paid_transaction_amount + bill.fees).to_i}</MONTANT>
              </Facture>
            </ArrayOfFacture>
          ]
      #end
    else
      result = %Q[
          <?xml version="1.0" encoding="utf-8"?>
          <ArrayOfFacture>

          </ArrayOfFacture>
        ]
    end

    render :xml => result
  end

  # SearchBill
  soap_action "SearchBill",
              :args   => { :Reference => :string },
              :return => :xml
  def SearchBill
    bill = MtnCi.find_by_transaction_id(params[:Reference])

    if bill
      result = %Q[
          <?xml version="1.0" encoding="utf-8" ?>
          <ArrayOfFacture xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="http://billrequest.billmanager.mtn.ci/">
            <Facture>
              <CODE>#{bill.transaction_id}</CODE>
              <NUMCLIENT>#{bill.process_online_client_number}</NUMCLIENT>
              <NUMFACTURE>#{bill.transaction_id}</NUMFACTURE>
              <DATEFACTURE>#{bill.created_at}</DATEFACTURE>
              <DELAIPAIEMENT>#{bill.created_at + 1.hour}</DELAIPAIEMENT>
              <MONTANT>#{(bill.paid_transaction_amount + bill.fees).to_i}</MONTANT>
            </Facture>
          </ArrayOfFacture>
        ]
    else
      result = %Q[
          <?xml version="1.0" encoding="utf-8"?>
          <ArrayOfFacture>

          </ArrayOfFacture>
        ]
    end

    render :xml => result
  end

  # PayBill
  soap_action "PayBill",
              :args   => { :User => :string, :Pass => :string, :Reference => :string, :Montant => :string, :Transact => :string },
              :return => :xml
  def PayBill
    OmLog.create(log_rl: params.to_s) rescue nil

    if params[:User] == "4153bbea-5eb3-4820-b760-040d16b06549" && params[:Pass] == "6c02d9c8e3d5eb4b451c6165d9180d8d"
      @bill = MtnCi.find_by_transaction_id(params[:Reference])

      if @bill
        if (@bill.paid_transaction_amount + @bill.fees).to_i == params[:Montant].to_i
          # Use MTN Money authentication_token
          update_wallet_used(@bill, "73007113fe")

          # Conversion du montant débité par le wallet et des frais en euro avant envoi pour notification au back office du hub
          @rate = get_change_rate("XAF", "EUR")

          @bill.update_attributes(payment_status: true, real_time_transact: params[:Transact], compensation_rate: @rate)

          @amount_for_compensation = ((@bill.paid_transaction_amount + @bill.fees) * @rate).round(2)
          @fees_for_compensation = (@bill.fees * @rate).round(2)

          # Notification au back office du hub
          notify_to_back_office(@bill, "#{ENV['second_origin_url']}/GATEWAY/rest/WS/#{@bill.operation.id}/#{@bill.number}/#{@bill.transaction_id}/#{@amount_for_compensation}/#{@fees_for_compensation}/2")

          # Update in available_wallet the number of successful_transactions
          update_number_of_succeed_transactions

          @status_id = 1

          # Handle GUCE notifications
          guce_request_payment?(@bill.service.authentication_token, 'QRTH45N', 'ELNPAY4')

          generic_ipn_notification(@bill)

          result = %Q[
              <?xml version="1.0" encoding="utf-8" ?>
              <Paiement xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="http://billrequest.billmanager.mtn.ci/">
                <CODE>0</CODE>
                <NUMFACTURE>#{@bill.transaction_id}</NUMFACTURE>
                <DATEPAIEMENT>#{@bill.updated_at}</DATEPAIEMENT>
                <MONTANT>#{(@bill.paid_transaction_amount + @bill.fees).to_i}</MONTANT>
                <COMMENTAIRE></COMMENTAIRE>
              </Paiement>
            ]
        else
          @bill.update_attributes(:conflictual_transaction_amount => params[:Montant].to_f, :conflictual_currency => "XAF")
          # Update in available_wallet the number of failed_transactions
          update_number_of_failed_transactions

          result = %Q[
            <?xml version="1.0" encoding="utf-8"?>
            <Error>
              Le montant de la facture est incorrect.
            </Error>
          ]
        end
      else
        result = %Q[
            <?xml version="1.0" encoding="utf-8"?>
            <Error>
              La facture n'a pas été trouvée.
            </Error>
          ]
      end
    else
      result = %Q[
            <?xml version="1.0" encoding="utf-8"?>
            <Error>
              Utilisateur non autorisé.
            </Error>
          ]
    end

    render :xml => result
  end

  def notify_to_back_office(basket, url)
    #if basket.payment_status != true
      #basket.update_attributes(:payment_status => true)
    #end
    @request = Typhoeus::Request.new(url, followlocation: true)
    @internal_com_request = "@response = Nokogiri.XML(request.response.body)
    @response.xpath('//status').each do |link|
    @status = link.content
    end
    "
    run_typhoeus_request(@request, @internal_com_request)

    if @status.to_s.strip == "1"
      basket.update_attributes(:notified_to_back_office => true)
    end
  end

  def generic_ipn_notification(basket)
    @service = Service.find_by_id(basket.service_id)
    @request = Typhoeus::Request.new("#{@service.url_to_ipn}?transaction_id=#{basket.transaction_id}&order_id=#{basket.number}&status_id=1&wallet=mtn_ci&transaction_amount=#{basket.original_transaction_amount}&currency=#{basket.currency.code}&paid_transaction_amount=#{basket.paid_transaction_amount}&paid_currency=#{Currency.find_by_id(basket.paid_currency_id).code}&change_rate=#{basket.rate}&id=#{basket.login_id}", followlocation: true, method: :post)
    # wallet=05ccd7ba3d
    @request.run
    @response = @request.response
    if @response.code.to_s == "200"
      basket.update_attributes(:notified_to_ecommerce => true)
    end
  end
end
