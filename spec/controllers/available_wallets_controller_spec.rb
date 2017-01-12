require 'rails_helper'

RSpec.describe AvailableWalletsController, type: :controller do
  describe '.enable_disable' do
    it 'should return json' do
      post :enable_disable
      expect(response.body).to include("status")
      expect(response.content_type).to eq('application/json')
    end
  end
end
