require 'rails_helper'

RSpec.describe WalletsController, type: :controller do
  describe 'GET get_wallets' do
    it 'routes to the get_wallets action' do
      expect(get: 'get_wallets')
        .to route_to(
          controller: 'wallets',
          action:     'get_wallets'
        )
    end
  end

  describe 'GET bfaad58e15f671064fd87277/wallets/edit/:authentication_token' do
    it 'routes to the edit action' do
      expect(get: 'bfaad58e15f671064fd87277/wallets/edit/gd5eg5dg8dg6dg8dgza')
        .to route_to(
          controller:           'wallets',
          action:               'edit',
          authentication_token: 'gd5eg5dg8dg6dg8dgza'
        )
    end
  end

  describe 'POST bfaad58e15f671064fd87277/wallets/update/:authentication_token' do
    it 'routes to the update action' do
      expect(post: 'bfaad58e15f671064fd87277/wallets/update/gd5eg5dg8dg6dg8dgza')
        .to route_to(
          controller:           'wallets',
          action:               'update',
          authentication_token: 'gd5eg5dg8dg6dg8dgza'
        )
    end
  end

  describe 'POST wallets/available' do
    it 'routes to the enable_disable action' do
      expect(post: 'wallets/available')
        .to route_to(
          controller: 'wallets',
          action:     'available'
        )
    end
  end

  describe 'POST wallets/used_per_country/:token' do
    it 'routes to the used_wallets_per_country action' do
      expect(post: 'wallets/used_per_country/ref5s4egg')
        .to route_to(
          controller: 'wallets',
          action:     'used_wallets_per_country',
          token:      'ref5s4egg'
        )
    end
  end

  describe 'POST wallet/successful_transactions/:service_token/:wallet_token' do
    it 'routes to the enable_disable action' do
      expect(post: 'wallet/successful_transactions/fopdk54dgeds521s41/q9sf2df8f45df9g4')
        .to route_to(
          controller:    'wallets',
          action:        'successful_transactions_per_service',
          service_token: 'fopdk54dgeds521s41',
          wallet_token:  'q9sf2df8f45df9g4'
        )
    end
  end

  describe 'POST wallet/failed_transactions/:service_token/:wallet_token' do
    it 'routes to the enable_disable action' do
      expect(post: 'wallet/failed_transactions/fopdk54dgeds521s41/q9sf2df8f45df9g4')
        .to route_to(
          controller:    'wallets',
          action:        'failed_transactions_per_service',
          service_token: 'fopdk54dgeds521s41',
          wallet_token:  'q9sf2df8f45df9g4'
        )
    end
  end
end
