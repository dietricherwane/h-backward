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
  
end
