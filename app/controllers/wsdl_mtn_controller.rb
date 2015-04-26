class WsdlMtnController < ApplicationController
  soap_service namespace: 'PayMoney:MTN:wsdl'

  # GetBill
  soap_action "GetBill",
              :args   => { :Reference => :string, :Montant => :integer },
              :return => :xml
  def GetBill
    bill = MtnCi.find_by_transaction_id(params[:Reference])

    if bill
      if (bill.paid_transaction_amount + bill.fees).to_i == params[:Montant].to_i
        result = %Q[
            <Facture>
              <CODE>#{bill.transaction_id}</CODE>
              <NUMCLIENT>string</NUMCLIENT>
              <NUMFACTURE>string</NUMFACTURE>
              <DATEFACTURE>dateTime</DATEFACTURE>
              <DELAIPAIEMENT>dateTime</DELAIPAIEMENT>
              <MONTANT>decimal</MONTANT>
            </Facture>
          ]
      end
    end

    render :xml => %Q[
          <?xml version="1.0" encoding="utf-8"?>
          <ArrayOfFacture xmlns="http://41.189.40.193:6968/">

          </ArrayOfFacture>
        ]
  end
end
