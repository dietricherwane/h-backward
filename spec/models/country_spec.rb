require 'spec_helper'

RSpec.describe Country, type: :model do
  describe '#default_country' do
    let(:country) { FactoryGirl.create(:country) }
    it 'returns a predifined string' do
      expect(country.default_country).to eq "International"
    end
  end
  
  describe 'code attribute' do
    let(:country) { FactoryGirl.create(:country) }
    it 'should be an instance of String' do
      expect(country.code.class).to eq String
    end
  end
  
  describe 'name attribute' do
    let(:country) { FactoryGirl.create(:country) }
    it 'should be an instance of String' do
      expect(country.name.class).to eq String
    end
  end
  
  describe 'published attribute' do
    let(:country) { FactoryGirl.create(:country) }
    it 'should be a boolean value' do
      expect(country.published.class).to eq FalseClass
    end
  end
end