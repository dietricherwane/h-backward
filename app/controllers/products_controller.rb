class ProductsController < ApplicationController

  def index
    @products = Product.all
  end

  def testing_json_parsing
    @request = Typhoeus::Request.new("http://0.0.0.0:3001/categories.json")
    hydra = Typhoeus::Hydra.hydra
		hydra.queue(@request)
		hydra.run

		@response = @request.response
		@parser = Yajl::Parser.new
		@my_hash = @parser.parse(@response.body)
  end

  def edit
  end

  def show
  end

  def create
  end

  def update
  end

  def delete
  end

  def guce
    response = Nokogiri.XML(%Q{<ns3:response xmlns= "epayment/common" xmlns:ns2= "epayment/common-response"
xmlns:ns3= "epayment/check-response" xmlns:ns4= "epayment/common-request" >
<ns2:header>
<message_id>Messages Error</message_id>
<operation>check</operation>
<ns2:result>1</ns2:result>
</ns2:header>
</ns3:response>})

    @order_id = (response.xpath('//ns2:result').text )
    #@amount = (response.xpath('//ns3:response').at('bill').at('amount').content )

  end

  # Make sure the order id is not null and amount is a number
  def valid_guce_params?
    if @order_id == nil || @amount == nil || not_a_number?(@amount)
      return false
    else
      return true
    end
  end

end
