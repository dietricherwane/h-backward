require 'rails_helper'

RSpec.describe OperationsController, type: :controller do
  describe "GET /operations" do
    it "" do
      get operations_index_path
      expect(response).to have_http_status(200)
    end
  end
end
