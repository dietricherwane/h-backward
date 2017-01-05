require 'rails_helper'

RSpec.describe PaymentWayFeesController, type: :controller do
  describe "GET /payment_way_fees" do
    it "" do
      get payment_way_fees_index_path
      expect(response).to have_http_status(200)
    end
  end
end
