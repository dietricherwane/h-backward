class WsdlMtnController < ApplicationController
  soap_service namespace: 'urn:WashOut'

  # GetBill
  soap_action "get_bill",
              :args   => { :Reference => :string },
              :return => :string
  def get_bill
    @bill = MtnCi.find_by_transaction_id(params[:Reference])

    render :soap => @bill.inspect.to_s
  end
end
