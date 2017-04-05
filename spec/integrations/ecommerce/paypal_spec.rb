require 'spec_helper'

RSpec.describe 'Hub entry point', type: :feature do
  context 'From e-commerce service (ARMA)' do
    currency = 'xof'
    service = Service.find_by(name: 'ARMA')
    order = service.mtn_cis.where(payment_status: false).first
    url = "order/#{currency}/#{service.code}/#{service.operations.first.authentication_token}/#{order.number}/#{order.transaction_amount}"
    
    describe 'Click on Paypal', js: true do
      before do
        Capybara.javascript_driver = :webkit
        # Capybara.current_driver = :webkit
      end
      it 'Page has link "paypal"' do
        visit url
        page.select('Portefeuille électronique', from: 'country[country_id]')
        wait_for_ajax
        expect(page).to have_selector('a.paypal', count: 1)
      end
      it 'Page has service name' do
        visit url
        page.select('Portefeuille électronique', from: 'country[country_id]')
        wait_for_ajax
        find('.paypal img').click
        # screenshot_and_save_page
        page.has_content? 'ARMA'
      end
      it 'Page has button with relevant text' do
        visit url
        page.select('Portefeuille électronique', from: 'country[country_id]')
        wait_for_ajax
        find('.paypal img').click
        page.has_content? 'Payer avec Paypal'
      end
      it 'Page has amount field' do
        visit url
        page.select('Portefeuille électronique', from: 'country[country_id]')
        wait_for_ajax
        find('.paypal img').click
        page.has_content? 'input#amount'
      end
      it 'Page has tax field' do
        visit url
        page.select('Portefeuille électronique', from: 'country[country_id]')
        wait_for_ajax
        find('.paypal img').click
        page.has_content? 'input#tax'
      end
      it 'Page has 2 input fields' do
        visit url
        page.select('Portefeuille électronique', from: 'country[country_id]')
        wait_for_ajax
        find('.paypal img').click
        expect(page.find(:xpath, '//form')).to have_selector('input' , count: 2)
      end
      # TODO: Test amount and tax values for Paypal
      # it 'Input "Transaction amount" has relevant value' do
      #   visit url
      #   page.select('Portefeuille électronique', from: 'country[country_id]')
      #   wait_for_ajax
      #   find('.paypal img').click
      #   expect(find('input#amount').value).to eq((page.get_rack_session_key('trs_amount') * @rate).round(2).to_s)
      # end
      # it 'Input "Frais" has relevant value' do
      #   visit url
      #   page.select('Portefeuille électronique', from: 'country[country_id]')
      #   wait_for_ajax
      #   find('.paypal img').click
      #   expect(find('input#tax').value).to eq(order.unceiled_shipping_fee.to_s)
      # end
    end
  end
end