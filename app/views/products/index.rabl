collection @products
attributes :id, :name, :price, :published
node(:is_published) { |product| product.published }
