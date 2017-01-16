require 'rails_helper'

RSpec.describe AvailableWalletsController, type: :routing do
  describe 'GET /mtn_ci/:service_id/:operation_id/:basket_number/:transaction_amount' do
    it 'routes to index action' do
      expect(get: '/mtn_ci/352611a357012392305333f18ef3c9bd/0e18096f-1f49-405b-b6c7-da376d7e65db/1d348tdgksi2b1122016/1000')
      	.to route_to(
        	controller:        'mtn_cis',
        	action: 	          'guard',
          service_id:         '352611a357012392305333f18ef3c9bd',
          operation_id:       '0e18096f-1f49-405b-b6c7-da376d7e65db',
          basket_number:      '1d348tdgksi2b1122016',
          transaction_amount: '1000',
        )
    end
  end

  describe 'GET /MTNCI' do
    it 'routes to index action' do
      expect(get: 'MTNCI').to route_to(
      	controller: 'mtn_cis',
      	action: 	'index'
      )
    end
  end

  describe 'POST /MTNCI/ecommerce_payment' do
    it 'routes to ecommerce_payment action' do
      expect(post: '/MTNCI/ecommerce_payment').to route_to(
      	controller: 'mtn_cis',
      	action: 	'ecommerce_payment'
      )
    end
  end

  describe 'POST /MTNCI/cashin_mobile' do
    it 'routes to cashin_mobile action' do
      expect(post: '/MTNCI/cashin_mobile').to route_to(
      	controller: 'mtn_cis',
      	action: 	'cashin_mobile'
      )
    end
  end

  describe 'POST /MTNCI/cashout_mobile' do
    it 'routes to cashout_mobile action' do
      expect(post: '/MTNCI/cashout_mobile').to route_to(
      	controller: 'mtn_cis',
      	action: 	'cashout_mobile'
      )
    end
  end

  describe 'POST /MTNCI/ipn' do
    it 'routes to ipn action' do
      expect(post: '/MTNCI/ipn').to route_to(
      	controller: 'mtn_cis',
      	action: 	'ipn'
      )
    end
  end

  describe 'POST /mtn_sdp_notification' do
    it 'routes to get_sdp_notification action' do
      expect(post: '/mtn_sdp_notification').to route_to(
      	controller: 'mtn_cis',
      	action: 	'get_sdp_notification'
      )
    end
  end

  describe 'GET /MTNCI/merchant_side_redirection' do
    it 'routes to merchant_side_redirection action' do
      expect(get: '/MTNCI/merchant_side_redirection').to route_to(
      	controller: 'mtn_cis',
      	action: 	'merchant_side_redirection'
      )
    end
  end

  describe 'GET /MTNCI/waiting_validation' do
    it 'routes to waiting_validation action' do
      expect(get: '/MTNCI/waiting_validation').to route_to(
      	controller: 'mtn_cis',
      	action: 	'waiting_validation'
      )
    end
  end

  describe 'GET /MTNCI/check_transaction_validation' do
    it 'routes to check_transaction_validation action' do
      expect(get: '/MTNCI/check_transaction_validation').to route_to(
      	controller: 'mtn_cis',
      	action: 	'check_transaction_validation'
      )
    end
  end

  describe 'POST /MTNCI/transaction_acknowledgement' do
    it 'routes to transaction_acknowledgement action' do
      expect(post: '/MTNCI/transaction_acknowledgement').to route_to(
      	controller: 'mtn_cis',
      	action: 	'transaction_acknowledgement'
      )
    end
  end

  describe 'POST /MTNCI/transaction_acknowledgement/:transaction_id' do
    it 'routes to transaction_acknowledgement action' do
      expect(post: '/MTNCI/transaction_acknowledgement/abc45').to route_to(
      	controller: 	'mtn_cis',
      	action: 		'transaction_acknowledgement',
      	transaction_id: 'abc45'
      )
    end
  end

  describe 'GET /MTNCI/transaction_acknowledgement/:transaction_id' do
    it 'routes to index action' do
      expect(get: '/MTNCI/transaction_acknowledgement/abc45').to route_to(
      	controller: 	'mtn_cis',
      	action: 		'transaction_acknowledgement',
      	transaction_id: 'abc45'
      )
    end
  end
end