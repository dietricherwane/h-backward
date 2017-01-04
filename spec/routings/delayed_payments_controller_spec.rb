require 'rails_helper'

RSpec.describe DelayedPaymentsController, type: :controller do
  describe 'GET /delayed_payments/:service_id/:operation_id/:basket_number/:transaction_amount' do
    it 'routes to the guard action' do
      expect(get: 'delayed_payments/780/120/98456321/5000')
        .to route_to(
          controller:         'delayed_payments',
          action:             'guard',
          service_id:         '780',
          operation_id:       '120',
          basket_number:      '98456321',
          transaction_amount: '5000'
        )
    end
  end

  describe 'GET /Delayed_Payment' do
    it 'routes to the  action' do
      expect(get: 'Delayed_Payment')
        .to route_to(
          controller: 'delayed_payments',
          action:     'index',
        )
    end
  end

  describe 'GET /delayed_payment_listener/:service_id/:operation_id/:basket_number/:transaction_amount' do
    it 'routes to the  action' do
      expect(get: 'delayed_payment_listener/780/120/98456321/5000')
        .to route_to(
          controller:         'delayed_payments',
          action:             'delayed_payment_listener',
          service_id:         '780',
          operation_id:       '120',
          basket_number:      '98456321',
          transaction_amount: '5000',
        )
    end
  end
end