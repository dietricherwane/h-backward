namespace :currencies do
  desc "Connect to http://rate-exchange.appspot.com/currency?from=USD&to=XAF and get changes rates"
  	task :get_changes => :environment do  
  	  @currencies = Currency.where("published IS TRUE")
  	  unless @currencies.blank?
  	    @currencies = @currencies.map{|currency| currency.code}
  	    @currencies.each do |from|
  	      from = from.upcase
  	      @currencies.each do |to|  	        
  	        to = to.upcase
  	        unless from == to
          	  @request = Typhoeus::Request.new("rate-exchange.appspot.com/currency?from=#{from}&to=#{to}", method: :get)
              @request.run
              @response = eval(@request.response.body.gsub(":", "=>")) rescue nil
              unless @response.blank? 
                @change_exists = ActiveRecord::Base.connection.execute("SELECT * FROM currencies_matches WHERE first_code = '#{from}' AND second_code = '#{to}'")
                if @change_exists.blank? or @change_exists.count == 0
                  ActiveRecord::Base.connection.execute("INSERT INTO currencies_matches(first_code, second_code, rate) VALUES('#{from}', '#{to}', #{@response["rate"].to_f * 0.98})")
                else
                  ActiveRecord::Base.connection.execute("UPDATE currencies_matches SET rate = #{@response["rate"].to_f * 0.98} WHERE first_code = '#{from}' AND second_code = '#{to}'")
                end
              end
            end
          end
        end
      end
  	end
end
