require 'spec_helper'

RSpec.describe 'Hub entry point', type: :feature do
  context 'From e-commerce service (ARMA)' do
    currency = 'xof'
    service = Service.find_by(name: 'ARMA')
    order = service.mtn_cis.where(payment_status: false).first
    url = "order/#{currency}/#{service.code}/#{service.operations.first.authentication_token}/#{order.number}/#{order.transaction_amount}"

    describe 'Click on PayMoney', js: true do
      before do
        Capybara.javascript_driver = :webkit
        # Capybara.current_driver = :webkit
      end
      it 'Page has link "paymoney"' do
        visit url
        page.select('Portefeuille électronique', from: 'country[country_id]')
        wait_for_ajax
        expect(page).to have_selector('a.paypal', count: 1)
      end
      it 'Page has service name' do
        visit url
        page.select('Portefeuille électronique', from: 'country[country_id]')
        wait_for_ajax
        find('.paymoney img').click
        page.has_content? 'ARMA'
      end
      it 'Page has button with relevant text' do
        visit url
        page.select('Portefeuille électronique', from: 'country[country_id]')
        wait_for_ajax
        find('.paymoney img').click
        page.has_content? 'Payer avec PayMoney'
      end
      it 'Page has amount field' do
        visit url
        page.select('Portefeuille électronique', from: 'country[country_id]')
        wait_for_ajax
        find('.paymoney img').click
        page.has_content? 'input#amount'
      end
      it 'Page has fees field' do
        visit url
        page.select('Portefeuille électronique', from: 'country[country_id]')
        wait_for_ajax
        find('.paymoney img').click
        page.has_content? 'input#fee'
      end
      it 'Page has paymoney account field' do
        visit url
        page.select('Portefeuille électronique', from: 'country[country_id]')
        wait_for_ajax
        find('.paymoney img').click
        page.has_css? 'input#colomb'
      end
      it 'Page has paymoney password field' do
        visit url
        page.select('Portefeuille électronique', from: 'country[country_id]')
        wait_for_ajax
        find('.paymoney img').click
        page.has_css? 'input#drake'
      end
      it 'Page has 4 input fields' do
        visit url
        page.select('Portefeuille électronique', from: 'country[country_id]')
        wait_for_ajax
        find('.paymoney img').click
        expect(page.find(:xpath, '//form')).to have_selector('input' , count: 4)
      end
      it 'Input "Transaction amount" has relevant value' do
        visit url
        page.select('Portefeuille électronique', from: 'country[country_id]')
        wait_for_ajax
        find('.paymoney img').click
        expect(find('input#magellan').value).to eq(order.transaction_amount.to_s)
      end
      it 'Input "Frais" has relevant value' do
        visit url
        page.select('Portefeuille électronique', from: 'country[country_id]')
        wait_for_ajax
        find('.paymoney img').click
        expect(find('input#Frais').value).to eq(order.fees.to_s)
      end
    end
  end
end