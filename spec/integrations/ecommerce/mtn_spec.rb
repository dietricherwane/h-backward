require 'spec_helper'

RSpec.describe 'Hub entry point', type: :feature do
  context 'From e-commerce service (ARMA)' do
    currency = 'xof'
    service = Service.find_by(name: 'ARMA')
    order = service.mtn_cis.where(payment_status: false).first
    url = "order/#{currency}/#{service.code}/#{service.operations.first.authentication_token}/#{order.number}/#{order.transaction_amount}"

    describe 'Click on MoMo', js: true do
      before do
        Capybara.javascript_driver = :webkit
        Capybara.current_driver = :webkit
      end
      it 'Page has link "mtn"' do
        visit url
        page.select('Portefeuille électronique', from: 'country[country_id]')
        wait_for_ajax
        expect(page).to have_selector('a.mtn', count: 1)
      end
      it 'Page has service name' do
        visit url
        page.select('Portefeuille électronique', from: 'country[country_id]')
        wait_for_ajax
        find('.mtn img').click
        page.has_content? 'ARMA'
      end
      it 'Page has button with relevant text' do
        visit url
        page.select('Portefeuille électronique', from: 'country[country_id]')
        wait_for_ajax
        find('.mtn img').click
        page.has_content? 'Payer avec Mtn Mobile Money'
      end
      it 'Page has 3 input fields' do
        visit url
        page.select('Portefeuille électronique', from: 'country[country_id]')
        wait_for_ajax
        find('.mtn img').click
        expect(page).to have_selector('input' , count: 3)
      end
      it 'Page has paymoney password field' do
        visit url
        page.select('Portefeuille électronique', from: 'country[country_id]')
        wait_for_ajax
        find('.mtn img').click
        page.has_css? 'input#mobile_mney_number'
      end
      it 'Input "Transaction amount" has relevant value' do
        visit url
        page.select('Portefeuille électronique', from: 'country[country_id]')
        wait_for_ajax
        find('.mtn img').click
        expect(find('input#payment_amount').value).to eq(order.transaction_amount.to_i.to_s)
      end
      it 'Input "Frais" has relevant value' do
        visit url
        page.select('Portefeuille électronique', from: 'country[country_id]')
        wait_for_ajax
        find('.mtn img').click
        expect(find('input#payment_fee').value).to eq(order.fees.to_s)
      end
    end
  end
end