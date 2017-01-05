require 'rails_helper'

RSpec.describe ServicesController, type: :routing do
  describe 'GET services' do
    it 'routes to the index action' do
      expect(get: 'services')
        .to route_to(
          controller: 'services',
          action:     'index'
        )
    end
  end
  
  describe 'GET service/create' do
    it 'routes to the create action' do
      expect(get: 'service/create')
        .to route_to(
          controller: 'services',
          action:     'create'
        )
    end
  end
  
  describe 'GET service/update' do
    it 'routes to the update action' do
      expect(get: 'service/update')
        .to route_to(
          controller: 'services',
          action:     'update'
        )
    end
  end
  
  describe 'GET service/disable' do
    it 'routes to the disable action' do
      expect(get: 'service/disable')
        .to route_to(
          controller: 'services',
          action:     'disable'
        )
    end
  end
  
  describe 'GET service/enable' do
    it 'routes to the enable action' do
      expect(get: 'service/enable')
        .to route_to(
          controller: 'services',
          action:     'enable'
        )
    end
  end
  
  describe 'POST service/qualify' do
    it 'routes to the  action' do
      expect(post: 'service/qualify')
        .to route_to(
          controller: 'services',
          action:     'qualify'
        )
    end
  end

  describe 'POST service/enable_disable' do
    it 'routes to the enable_disable action' do
      expect(post: 'service/enable_disable')
        .to route_to(
          controller: 'services',
          action:     'enable_disable'
        )
    end
  end
end
