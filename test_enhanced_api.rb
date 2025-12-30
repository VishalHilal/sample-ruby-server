require "net/http"
require "json"
require "uri"

class EnhancedAPITester
  BASE_URL = "http://localhost:3000"
  API_KEY = nil
  
  def self.run_tests
    puts "🚀 Running Enhanced API Tests with New Features..."
    puts "=" * 60
    
    # Test 1: Root endpoint
    test_root_endpoint
    
    # Test 2: Health check
    test_health_endpoint
    
    # Test 3: Register user and get API key
    API_KEY = test_register_user
    
    # Test 4: Upload image
    image_url = test_image_upload
    
    # Test 5: Create product with image and stock
    product_id = test_create_product_with_image(image_url)
    
    # Test 6: Create review for product
    review_id = test_create_review(product_id)
    
    # Test 7: Get product reviews
    test_get_product_reviews(product_id)
    
    # Test 8: Get all products (with new fields)
    test_get_products
    
    # Test 9: Update product (add stock)
    test_update_product_stock(product_id)
    
    # Test 10: Search products
    test_search_products
    
    # Test 11: Get specific product
    test_get_product(product_id) if product_id
    
    # Test 12: Test validation
    test_validation
    
    # Test 13: Test authentication failure
    test_auth_failure
    
    # Test 14: Delete product
    test_delete_product(product_id) if product_id
    
    # Test 15: Metrics endpoint
    test_metrics_endpoint
    
    # Test 16: Rate limiting
    test_rate_limiting
    
    puts "=" * 60
    puts "✅ All enhanced tests completed!"
  end
  
  def self.make_request(method, path, body = nil, headers = {})
    uri = URI("#{BASE_URL}#{path}")
    
    request_headers = { "Content-Type" => "application/json" }
    request_headers.merge!(headers) if headers.any?
    
    case method.upcase
    when "GET"
      req = Net::HTTP::Get.new(uri)
      request_headers.each { |k, v| req[k] = v }
      Net::HTTP.start(uri.host, uri.port) { |http| http.request(req) }
    when "POST"
      req = Net::HTTP::Post.new(uri)
      request_headers.each { |k, v| req[k] = v }
      req.body = body&.to_json
      Net::HTTP.start(uri.host, uri.port) { |http| http.request(req) }
    when "PUT"
      req = Net::HTTP::Put.new(uri)
      request_headers.each { |k, v| req[k] = v }
      req.body = body&.to_json
      Net::HTTP.start(uri.host, uri.port) { |http| http.request(req) }
    when "DELETE"
      req = Net::HTTP::Delete.new(uri)
      request_headers.each { |k, v| req[k] = v }
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
      puts "   Available endpoints: #{data['endpoints'].keys.length}"
    else
      puts "❌ Root endpoint failed"
    end
  end
  
  def self.test_health_endpoint
    puts "\n📍 Testing GET /health"
    response = make_request("GET", "/health")
    
    if response && response.code == "200"
      puts "✅ Health check working"
      data = JSON.parse(response.body)
      puts "   Status: #{data['status']}, Database: #{data['database']}"
    else
      puts "❌ Health check failed"
    end
  end
  
  def self.test_register_user
    puts "\n📍 Testing POST /auth/register"
    user_data = {
      username: "testuser_#{Time.now.to_i}",
      email: "test#{Time.now.to_i}@example.com",
      password: "testpass123"
    }
    
    response = make_request("POST", "/auth/register", user_data)
    
    if response && response.code == "201"
      puts "✅ User registration successful"
      data = JSON.parse(response.body)
      puts "   API Key: #{data['api_key'][0, 10]}..."
      data['api_key']
    else
      puts "❌ User registration failed: #{response&.code}"
      nil
    end
  end
  
  def self.test_image_upload
    puts "\n📍 Testing POST /upload"
    
    # Create a simple test image (1x1 pixel PNG)
    png_data = Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg==")
    
    headers = API_KEY ? { "Authorization" => "Bearer #{API_KEY}", "Content-Type" => "image/png" } : {}
    response = upload_file_request("/upload", png_data, headers)
    
    if response && response.code == "201"
      puts "✅ Image upload successful"
      data = JSON.parse(response.body)
      puts "   File: #{data['file']['filename']}"
      data['file']['path']
    else
      puts "❌ Image upload failed: #{response&.code}"
      nil
    end
  end
  
  def self.upload_file_request(path, data, headers)
    uri = URI("#{BASE_URL}#{path}")
    req = Net::HTTP::Post.new(uri)
    headers.each { |k, v| req[k] = v }
    req.body = data
    Net::HTTP.start(uri.host, uri.port) { |http| http.request(req) }
  rescue => e
    puts "❌ Upload failed: #{e.message}"
    nil
  end
  
  def self.test_create_product_with_image(image_url)
    puts "\n📍 Testing POST /products (with image and stock)"
    product_data = {
      name: "Premium Laptop",
      price: "1299.99",
      category: "electronics",
      image_url: image_url,
      stock: 50
    }
    
    headers = API_KEY ? { "Authorization" => "Bearer #{API_KEY}" } : {}
    response = make_request("POST", "/products", product_data, headers)
    
    if response && response.code == "201"
      puts "✅ Product created with image and stock"
      product = JSON.parse(response.body)
      puts "   Product ID: #{product['id']}, Stock: #{product['stock']}"
      product['id']
    else
      puts "❌ Product creation failed: #{response&.code}"
      nil
    end
  end
  
  def self.test_create_review(product_id)
    puts "\n📍 Testing POST /reviews"
    review_data = {
      product_id: product_id,
      rating: 5,
      comment: "Excellent product! Highly recommended."
    }
    
    headers = API_KEY ? { "Authorization" => "Bearer #{API_KEY}" } : {}
    response = make_request("POST", "/reviews", review_data, headers)
    
    if response && response.code == "201"
      puts "✅ Review created successfully"
      review = JSON.parse(response.body)
      puts "   Review ID: #{review['id']}, Rating: #{review['rating']}"
      review['id']
    else
      puts "❌ Review creation failed: #{response&.code}"
      nil
    end
  end
  
  def self.test_get_product_reviews(product_id)
    puts "\n📍 Testing GET /product/reviews?product_id=#{product_id}"
    response = make_request("GET", "/product/reviews?product_id=#{product_id}")
    
    if response && response.code == "200"
      puts "✅ Product reviews retrieved"
      data = JSON.parse(response.body)
      puts "   Reviews: #{data['reviews'].length}, Avg Rating: #{data['rating_summary']['average_rating']}"
    else
      puts "❌ Reviews retrieval failed"
    end
  end
  
  def self.test_get_products
    puts "\n📍 Testing GET /products"
    response = make_request("GET", "/products")
    
    if response && response.code == "200"
      puts "✅ Products list retrieved"
      data = JSON.parse(response.body)
      puts "   Total products: #{data['pagination']['total_items']}"
      if data['products'].any?
        product = data['products'].first
        puts "   First product has image: #{!product['image_url'].nil?}, Stock: #{product['stock']}"
      end
    else
      puts "❌ Products list failed"
    end
  end
  
  def self.test_update_product_stock(product_id)
    puts "\n📍 Testing PUT /product?id=#{product_id} (update stock)"
    update_data = { stock: 25 }
    
    headers = API_KEY ? { "Authorization" => "Bearer #{API_KEY}" } : {}
    response = make_request("PUT", "/product?id=#{product_id}", update_data, headers)
    
    if response && response.code == "200"
      puts "✅ Product stock updated"
      product = JSON.parse(response.body)
      puts "   New stock: #{product['stock']}"
    else
      puts "❌ Product update failed: #{response&.code}"
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
      puts "   Product: #{product['name']}, Image: #{product['image_url'] ? 'Yes' : 'No'}"
    else
      puts "❌ Product retrieval failed"
    end
  end
  
  def self.test_validation
    puts "\n📍 Testing validation (empty product)"
    response = make_request("POST", "/products", {})
    
    if response && response.code == "401"
      puts "✅ Authentication required for product creation"
    elsif response && response.code == "400"
      puts "✅ Validation working correctly"
      errors = JSON.parse(response.body)
      puts "   Errors: #{errors['errors'].join(', ')}"
    else
      puts "❌ Validation failed: #{response&.code}"
    end
  end
  
  def self.test_auth_failure
    puts "\n📍 Testing authentication failure"
    product_data = { name: "Unauthorized Product", price: "99.99" }
    response = make_request("POST", "/products", product_data)
    
    if response && response.code == "401"
      puts "✅ Authentication properly enforced"
    else
      puts "❌ Authentication not working: #{response&.code}"
    end
  end
  
  def self.test_delete_product(product_id)
    puts "\n📍 Testing DELETE /product?id=#{product_id}"
    
    headers = API_KEY ? { "Authorization" => "Bearer #{API_KEY}" } : {}
    response = make_request("DELETE", "/product?id=#{product_id}", nil, headers)
    
    if response && response.code == "200"
      puts "✅ Product deleted successfully"
    else
      puts "❌ Product deletion failed: #{response&.code}"
    end
  end
  
  def self.test_metrics_endpoint
    puts "\n📍 Testing GET /metrics"
    response = make_request("GET", "/metrics")
    
    if response && response.code == "200"
      puts "✅ Metrics endpoint working"
      data = JSON.parse(response.body)
      puts "   Total requests: #{data['total_requests']}"
      puts "   Avg response time: #{data['avg_response_time']&.round(2)}ms"
    else
      puts "❌ Metrics failed"
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
  EnhancedAPITester.run_tests
end
