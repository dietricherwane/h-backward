require 'rails_helper'

RSpec.describe MainController, type: :controller do
  describe 'GET /Main' do
    it 'routes to the index action' do
      expect(get: '/Main')
        .to route_to(
          controller: 'main',
          action:     'index'
        )
    end
  end

  # Achats e-commerce
  describe 'GET order/:currency/:service_token/:operation_token/:order/:transaction_amount/:id' do
    it 'routes to the guard action' do
      expect(get: 'order/XOF/81d925f34f93/ba823ef11a3b/9574562/15000/10')
        .to route_to(
          controller:         'main',
          action:             'guard',
          currency:           'XOF',
          service_token:      '81d925f34f93',
          operation_token:    'ba823ef11a3b',
          order:              '9574562',
          transaction_amount: '15000',
          id:                 '10'
        )
    end
  end

  describe 'GET order/:currency/:service_token/:operation_token/:order/:transaction_amount' do
    it 'routes to the guard action' do
      expect(get: 'order/XOF/81d925f34f93/ba823ef11a3b/9574562/15000')
        .to route_to(
          controller:         'main',
          action:             'guard',
          currency:           'XOF',
          service_token:      '81d925f34f93',
          operation_token:    'ba823ef11a3b',
          order:              '9574562',
          transaction_amount: '15000'
        )
    end
  end

  # describe 'GET order/:currency/:service_token/:operation_token/:order/:transaction_amount' do
  #   it 'routes to the guard action' do
  #     expect(get: 'order/xof/af1a30551acd531383e605d7c1afbbe2/3d20d7af-2ecb-4681-8e4f-a585d7700ee4/XHJOHDMQ16455/500')
  #       .to redirect_to(action: "index")
  #   end
  # end

  # Rechargement de compte PayMoney
  describe 'GET /order/reload/:currency/:service_token/:operation_token/:order/:transaction_amount/:paymoney_account_number' do
    it 'routes to the guard action' do
      expect(get: '/order/reload/XOF/81d925f34f93/ba823ef11a3b/9574562/15000/464651325')
        .to route_to(
          controller:              'main',
          action:                  'guard',
          currency:                'XOF',
          service_token:           '81d925f34f93',
          operation_token:         'ba823ef11a3b',
          order:                   '9574562',
          transaction_amount:      '15000',
          paymoney_account_number: '464651325'
        )
    end
  end

  # Déchargement de compte PayMoney
  describe 'GET /order/unload/:currency/:service_token/:operation_token/:order/:transaction_amount/:paymoney_account_number/:paymoney_password' do
    it 'routes to the guard action' do
      expect(get: '/order/unload/XOF/81d925f34f93/ba823ef11a3b/9574562/15000/464651325/password')
        .to route_to(
          controller:              'main',
          action:                  'guard',
          currency:                'XOF',
          service_token:           '81d925f34f93',
          operation_token:         'ba823ef11a3b',
          order:                   '9574562',
          transaction_amount:      '15000',
          paymoney_account_number: '464651325',
          paymoney_password:       'password'
        )
    end
  end
end
