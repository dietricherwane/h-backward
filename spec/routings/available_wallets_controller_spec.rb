require 'rails_helper'

RSpec.describe AvailableWalletsController, type: :routing do
  describe 'POST available_wallet/enable_disable' do
    it 'routes to the enable_disable action' do
      expect(post: 'available_wallet/enable_disable')
        .to route_to(
          controller: 'available_wallets',
          action:     'enable_disable'
        )
    end
  end
end