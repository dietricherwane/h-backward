require 'rails_helper'

RSpec.describe ReportsController, type: :controller do
  describe "GET /reports" do
    it "" do
      get reports_index_path
      expect(response).to have_http_status(200)
    end
  end
end
