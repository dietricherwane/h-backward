namespace :currencies do
  desc "Connect to https://currencylayer.com and get changes rates"
  	task :get_changes => :environment do
  	  @currencies = Currency.where("published IS TRUE")
  	  unless @currencies.blank?
  	    @currencies = @currencies.map{|currency| currency.code}
  	    @currencies.each do |from|
  	      from = from.upcase
  	      @currencies.each do |to|
  	        to = to.upcase
  	        unless from == to
          	  @request = Typhoeus::Request.new("http://apilayer.net/api/live?access_key=3ff2b63b0f2219858333df046e99f541&currencies=#{to}&source=#{from}", method: :get)
              @request.run
              @response = eval(@request.response.body.gsub(":", "=>")) rescue nil
              unless @response.blank?
                @change_exists = ActiveRecord::Base.connection.execute("SELECT * FROM currencies_matches WHERE first_code = '#{from}' AND second_code = '#{to}'")
                change_amount = @response["#{from + to}"].to_f
                if @change_exists.blank? or @change_exists.count == 0
                  ActiveRecord::Base.connection.execute("INSERT INTO currencies_matches(first_code, second_code, rate) VALUES('#{from}', '#{to}', #{change_amount})")
                else
                  ActiveRecord::Base.connection.execute("UPDATE currencies_matches SET rate = #{change_amount} WHERE first_code = '#{from}' AND second_code = '#{to}'")
                end
              end
            end
          end
        end
      end
  	end
end
