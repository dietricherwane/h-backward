require 'rails_helper'

RSpec.describe PaymentWayFeesController, type: :routing do
  describe 'GET payment_way_fee/create' do
    it 'routes to the create action' do
      expect(get: 'payment_way_fee/create')
        .to route_to(
          controller: 'payment_way_fees',
          action:     'create'
        )
    end
  end

  describe 'GET payment_way_fee/update' do
    it 'routes to the update action' do
      expect(get: 'payment_way_fee/update')
        .to route_to(
          controller: 'payment_way_fees',
          action:     'update'
        )
    end
  end
end
