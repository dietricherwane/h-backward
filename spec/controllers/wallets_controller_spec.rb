require 'rails_helper'

RSpec.describe WalletsController, type: :controller do
  describe "GET /wallets" do
    it "" do
      get wallets_index_path
      expect(response).to have_http_status(200)
    end
  end
end
