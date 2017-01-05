require 'rails_helper'

RSpec.describe ServicesController, type: :controller do
  describe "GET /services" do
    it "" do
      get services_index_path
      expect(response).to have_http_status(200)
    end
  end
end
