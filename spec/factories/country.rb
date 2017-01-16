require 'faker'

FactoryGirl.define do
  to_create { |instance| skip_create }
	factory :country do |f|
    f.code { Faker::Address.country_code }
    f.name { Faker::Address.country }
    f.published { Faker::Boolean.boolean(0.1) }
	end
end