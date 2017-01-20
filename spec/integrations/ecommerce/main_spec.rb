require 'spec_helper'

RSpec.describe 'Hub entry point', type: :feature do
  context 'From e-commerce service (ARMA)' do
    currency = 'xof'
    service = Service.find_by(name: 'ARMA')
    order = service.mtn_cis.where(payment_status: false).first
    url = "order/#{currency}/#{service.code}/#{service.operations.first.authentication_token}/#{order.number}/#{order.transaction_amount}"
    
    describe 'To Hub index page' do
      it 'should have service name' do
        visit url
        page.has_content? service.name
      end
      it 'should have two bank wallet' do
        visit url
        select('Banques', from: 'country[country_id]')
        links = all('#wallets_list a.wallet_link').count
        expect(links).to eq 2
      end
      before do
        Capybara.javascript_driver = :webkit
        Capybara.current_driver = :webkit
      end
      it 'should have five wallets', js: true do
        visit url
        page.select('Portefeuille électronique', from: 'country[country_id]')
        wait_for_ajax
        # screenshot_and_save_page
        links = all('#wallets_list a.wallet_link').count
        expect(links).to eq 5
      end
    end
  end
end