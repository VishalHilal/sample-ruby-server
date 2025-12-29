require "net/http"
require "json"
require "uri"

class APITester
  BASE_URL = "http://localhost:3000"
  
  def self.run_tests
    puts "🧪 Running API Tests..."
    puts "=" * 50
    
    # Test 1: Root endpoint
    test_root_endpoint
    
    # Test 2: Create product
    product_id = test_create_product
    
    # Test 3: Get all products
    test_get_products
    
    # Test 4: Search products
    test_search_products
    
    # Test 5: Get specific product
    test_get_product(product_id) if product_id
    
    # Test 6: Update product
    test_update_product(product_id) if product_id
    
    # Test 7: Test validation
    test_validation
    
    # Test 8: Delete product
    test_delete_product(product_id) if product_id
    
    # Test 9: Rate limiting
    test_rate_limiting
    
    puts "=" * 50
    puts "✅ All tests completed!"
  end
  
  def self.make_request(method, path, body = nil)
    uri = URI("#{BASE_URL}#{path}")
    
    case method.upcase
    when "GET"
      Net::HTTP.get_response(uri)
    when "POST"
      Net::HTTP.post(uri, body&.to_json, "Content-Type" => "application/json")
    when "PUT"
      req = Net::HTTP::Put.new(uri)
      req["Content-Type"] = "application/json"
      req.body = body&.to_json
      Net::HTTP.start(uri.host, uri.port) { |http| http.request(req) }
    when "DELETE"
      req = Net::HTTP::Delete.new(uri)
      Net::HTTP.start(uri.host, uri.port) { |http| http.request(req) }
    end
  rescue => e
    puts "❌ Request failed: #{e.message}"
    nil
  end
  
  def self.test_root_endpoint
    puts "\n📍 Testing GET /"
    response = make_request("GET", "/")
    
    if response && response.code == "200"
      puts "✅ Root endpoint working"
      data = JSON.parse(response.body)
      puts "   Available endpoints: #{data['endpoints'].keys.join(', ')}"
    else
      puts "❌ Root endpoint failed"
    end
  end
  
  def self.test_create_product
    puts "\n📍 Testing POST /products"
    product_data = {
      name: "Test Laptop",
      price: "999.99",
      category: "electronics"
    }
    
    response = make_request("POST", "/products", product_data)
    
    if response && response.code == "201"
      puts "✅ Product created successfully"
      product = JSON.parse(response.body)
      puts "   Product ID: #{product['id']}"
      product['id']
    else
      puts "❌ Product creation failed: #{response&.code}"
      nil
    end
  end
  
  def self.test_get_products
    puts "\n📍 Testing GET /products"
    response = make_request("GET", "/products")
    
    if response && response.code == "200"
      puts "✅ Products list retrieved"
      data = JSON.parse(response.body)
      puts "   Total products: #{data['pagination']['total_items']}"
    else
      puts "❌ Products list failed"
    end
  end
  
  def self.test_search_products
    puts "\n📍 Testing GET /products?search=laptop"
    response = make_request("GET", "/products?search=laptop")
    
    if response && response.code == "200"
      puts "✅ Search functionality working"
      data = JSON.parse(response.body)
      puts "   Found #{data['pagination']['total_items']} products"
    else
      puts "❌ Search failed"
    end
  end
  
  def self.test_get_product(product_id)
    puts "\n📍 Testing GET /product?id=#{product_id}"
    response = make_request("GET", "/product?id=#{product_id}")
    
    if response && response.code == "200"
      puts "✅ Product retrieved successfully"
      product = JSON.parse(response.body)
      puts "   Product: #{product['name']}"
    else
      puts "❌ Product retrieval failed"
    end
  end
  
  def self.test_update_product(product_id)
    puts "\n📍 Testing PUT /product?id=#{product_id}"
    update_data = { price: "899.99" }
    
    response = make_request("PUT", "/product?id=#{product_id}", update_data)
    
    if response && response.code == "200"
      puts "✅ Product updated successfully"
      product = JSON.parse(response.body)
      puts "   New price: $#{product['price']}"
    else
      puts "❌ Product update failed"
    end
  end
  
  def self.test_validation
    puts "\n📍 Testing validation (empty product)"
    response = make_request("POST", "/products", {})
    
    if response && response.code == "400"
      puts "✅ Validation working correctly"
      errors = JSON.parse(response.body)
      puts "   Errors: #{errors['errors'].join(', ')}"
    else
      puts "❌ Validation failed"
    end
  end
  
  def self.test_delete_product(product_id)
    puts "\n📍 Testing DELETE /product?id=#{product_id}"
    response = make_request("DELETE", "/product?id=#{product_id}")
    
    if response && response.code == "200"
      puts "✅ Product deleted successfully"
    else
      puts "❌ Product deletion failed"
    end
  end
  
  def self.test_rate_limiting
    puts "\n📍 Testing rate limiting (making 105 requests)"
    
    # Make 105 requests quickly to test rate limiting
    success_count = 0
    105.times do |i|
      response = make_request("GET", "/products")
      success_count += 1 if response && response.code == "200"
    end
    
    if success_count < 105
      puts "✅ Rate limiting working (only #{success_count}/105 succeeded)"
    else
      puts "⚠️  Rate limiting may not be active"
    end
  end
end

# Run tests if this file is executed directly
if __FILE__ == $0
  APITester.run_tests
end
