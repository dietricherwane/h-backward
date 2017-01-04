require 'rails_helper'

RSpec.describe OperationsController, type: :controller do
  describe 'GET operation/create' do
    it 'routes to the create action' do
      expect(get: 'operation/create')
        .to route_to(
          controller: 'operations',
          action:     'create'
        )
    end
  end

  describe 'GET operation/update' do
    it 'routes to the update action' do
      expect(get: 'operation/update')
        .to route_to(
          controller: 'operations',
          action:     'update'
        )
    end
  end

  describe 'GET operation/disable' do
    it 'routes to the disable action' do
      expect(get: 'operation/disable')
        .to route_to(
          controller: 'operations',
          action:     'disable'
        )
    end
  end

	describe 'GET ' do
    it 'routes to the enable action' do
      expect(get: 'operation/enable')
        .to route_to(
          controller: 'operations',
          action:     'enable'
        )
    end
  end
end
