require 'spec_helper'

RSpec.describe 'Hub entry point', type: :feature do
  context 'From e-commerce service (ARMA)' do
    currency = 'xof'
    service = Service.find_by(name: 'ARMA')
    order = service.mtn_cis.where(payment_status: false).first
    url = "order/#{currency}/#{service.code}/#{service.operations.first.authentication_token}/#{order.number}/#{order.transaction_amount}"

    describe 'Click on Uba' do
      before do
        Capybara.javascript_driver = :webkit
        # Capybara.current_driver = :webkit
      end
      it 'Page has link "uba"', js: true do
        visit url
        page.select('Banques', from: 'country[country_id]')
        wait_for_ajax
        expect(page).to have_selector('a.uba', count: 1)
      end
      it 'Page has service name' do
        visit url
        click_on('uba')
        page.has_content? 'ARMA'
      end
      it 'Page has button with relevant text' do
        visit url
        click_on('uba')
        page.has_content? 'Payer avec UBA'
      end
      it 'Page has amount field' do
        visit url
        click_on('uba')
        page.has_content? 'input#amount'
      end
      it 'Page has fees field' do
        visit url
        click_on('uba')
        page.has_content? 'input#fee'
      end
      it 'Page has firstname field' do
        visit url
        click_on('uba')
        page.has_css? 'input#firstname'
      end
      it 'Page has lastname field' do
        visit url
        click_on('uba')
        page.has_css? 'input#lastname'
      end
      it 'Page has email field' do
        visit url
        click_on('uba')
        page.has_css? 'input#email'
      end
      it 'Page has msisdn field' do
        visit url
        click_on('uba')
        page.has_css? 'input#msisdn'
      end
      it 'Page has 6 input fields' do
        visit url
        click_on('uba')
        expect(page.find(:xpath, '//form')).to have_selector('input' , count: 6)
      end
      it 'Input "Transaction amount" has relevant value' do
        visit url
        click_on('uba')
        expect(find('input#amount').value).to eq(order.transaction_amount.to_i.to_s)
      end
      it 'Input "Frais" has relevant value' do
        visit url
        click_on('uba')
        expect(find('input#fee').value).to eq(order.fees.to_s)
      end
    end
  end
end