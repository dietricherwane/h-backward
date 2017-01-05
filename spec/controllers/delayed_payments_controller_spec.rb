require 'rails_helper'

RSpec.describe DelayedPaymentsController, type: :controller do
  describe ".index" do
    it "should have status 200" do
      get :index
      expect(response.body).to eq('ok')
      # follow_redirect!
      # expect(response.body).to eq('ok')
    end
  end

  context '' do
    # New data for test purpose
    subject(:service) { Service.create(
        code:                 '317913d1b19c60b6bcafg80bn29b8hd7', 
        name:                 'Service for test',
        authentication_token: '317913d1b19c60b6bcafg80bn29b8hd7'
      )
    }
    subject(:operation) { Operation.create(
        code:                 'd5dff4be-05c1-4150-a966-0db47858f82v',
        service_id:           service.id,
        authentication_token: 'd5dff4be-05c1-4150-a966-0db47858f82v'
      )
    }
    subject(:delayed_payment) { DelayedPayment.create(
        number:             'KGBJFV5641HFFV',
        transaction_amount: 3000,
        service_id:         service.id,
        operation_id:       operation.id
      )
    }

    describe "GET /delayed_payment/:service_id/:operation_id/:basket_number/:transaction_amount" do

      it "should redirect to index" do
        get "delayed_payment/#{service.id}/#{operation.id}/#{delayed_payment.number}/#{delayed_payment.transaction_amount}"
        # expect(response).to redirect_to(action: 'index')
        expect(response).to redirect_to(action: 'index')
      end
    end

    describe "GET /delayed_payment_listener/:service_id/:operation_id/:basket_number/:transaction_amount" do
      it "should render delayed_payment_listener view" do
        get "delayed_payment_listener/#{service.id}/#{operation.id}/#{delayed_payment.number}/#{delayed_payment.transaction_amount}"
        expect(response).to render_template("delayed_payments/delayed_payment_listener.xml.builder")
      end
    end
  end
end
