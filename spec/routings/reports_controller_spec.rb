require 'rails_helper'

RSpec.describe ReportsController, type: :controller do
  describe 'GET Wimboo/Reports/Operations' do
    it 'routes to the wimboo_operations action' do
      expect(get: 'Wimboo/Reports/Operations')
        .to route_to(
          controller: 'reports',
          action:     'wimboo_operations'
        )
    end
  end

  describe 'POST Wimboo/FilterOperations' do
    it 'routes to the filter_wimboo_operations action' do
      expect(post: 'Wimboo/FilterOperations')
        .to route_to(
          controller: 'reports',
          action:     'filter_wimboo_operations'
        )
    end
  end

  describe 'GET Wimboo/Reports/AyantsDroit' do
    it 'routes to the wimboo_ayants_droit action' do
      expect(get: 'Wimboo/Reports/AyantsDroit')
        .to route_to(
          controller: 'reports',
          action:     'wimboo_ayants_droit'
        )
    end
  end

  describe 'GET E-kiosk/Reports/Operations' do
    it 'routes to the gepci_operations action' do
      expect(get: 'E-kiosk/Reports/Operations')
        .to route_to(
          controller: 'reports',
          action:     'gepci_operations'
        )
    end
  end

  describe 'POST E-kiosk/FilterOperations' do
    it 'routes to the filter_gepci_operations action' do
      expect(post: 'E-kiosk/FilterOperations')
        .to route_to(
          controller: 'reports',
          action:     'filter_gepci_operations'
        )
    end
  end

  describe 'GET E-kiosk/Reports/AyantsDroit' do
    it 'routes to the gepci_ayants_droit action' do
      expect(get: 'E-kiosk/Reports/AyantsDroit')
        .to route_to(
          controller: 'reports',
          action:     'gepci_ayants_droit'
        )
    end
  end
end
