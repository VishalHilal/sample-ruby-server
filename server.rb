require "webrick"
require "json"
require "sqlite3"
require "base64"
require "digest"
require "bcrypt"
require_relative "middleware"
require_relative "database"
require_relative "auth"
require_relative "file_upload"

server = WEBrick::HTTPServer.new(
  Port: 3000
)

# Database and authentication
$db = Database.new
$start_time = Time.now

# Static file serving for uploads
server.mount("/uploads", WEBrick::HTTPServlet::FileHandler, File.join(Dir.pwd, "public", "uploads"))

# Helper to parse JSON body
def parse_body(req)
  JSON.parse(req.body)
rescue JSON::ParserError
  {}
end

# Helper to set CORS headers
def set_cors_headers(res)
  res["Access-Control-Allow-Origin"] = "*"
  res["Access-Control-Allow-Methods"] = "GET, POST, PUT, DELETE, OPTIONS"
  res["Access-Control-Allow-Headers"] = "Content-Type"
end

# Helper to validate product data
def validate_product_data(data, required_fields = ["name", "price"])
  errors = []
  
  required_fields.each do |field|
    errors << "#{field} is required" if data[field].nil? || data[field].to_s.strip.empty?
  end
  
  if data["price"] && !(data["price"] =~ /^\d+(\.\d{1,2})?$/)
    errors << "Price must be a valid number"
  end
  
  errors
end

# Helper to sanitize product data
def sanitize_product_data(data)
  {
    name: Sanitizer.clean_string(data["name"]),
    price: Sanitizer.clean_price(data["price"]),
    category: Sanitizer.clean_string(data["category"])
  }
end

# Helper to send JSON response
def send_json_response(res, data, status = 200)
  res.status = status
  res["Content-Type"] = "application/json"
  set_cors_headers(res)
  res.body = data.is_a?(String) ? data : JSON.pretty_generate(data)
end

# Middleware to apply to all requests
def apply_middleware(req, res)
  start_time = Time.now
  
  # Rate limiting
  unless $rate_limiter.allow_request?(req.remote_ip)
    send_json_response(res, { error: "Rate limit exceeded. Try again later." }, 429)
    return false
  end
  
  # Continue with request
  result = yield
  
  # Log request to database
  response_time = ((Time.now - start_time) * 1000).round(2)
  $db.log_request(
    req.request_method,
    req.path,
    res.status,
    response_time,
    req.remote_ip,
    req['User-Agent']
  )
  
  # Console logging
  RequestLogger.log_request(req, res, start_time)
  
  result
end

# Authentication middleware
def require_auth(req, res)
  user = AuthManager.authenticate_request(req, $db)
  unless user
    send_json_response(res, { error: "Authentication required" }, 401)
    return false
  end
  user
end

# Root route
server.mount_proc "/" do |req, res|
  apply_middleware(req, res) do
    send_json_response(res, {
      message: "Ruby Business App API Running",
      endpoints: {
        "GET /" => "API information",
        "GET /health" => "Health check endpoint",
        "GET /metrics" => "API performance metrics",
        "POST /auth/register" => "Register user and get API key",
        "POST /upload" => "Upload product image (requires auth)",
        "GET /products" => "List all products (supports pagination and search)",
        "POST /products" => "Create a new product (requires auth)",
        "GET /product?id=:id" => "Get a specific product",
        "PUT /product?id=:id" => "Update a specific product (requires auth)",
        "DELETE /product?id=:id" => "Delete a specific product (requires auth)",
        "POST /reviews" => "Create product review (requires auth)",
        "GET /product/reviews?product_id=:id" => "Get product reviews and ratings"
      },
      examples: {
        create_product: { name: "Example Product", price: "29.99", category: "electronics" },
        pagination: "GET /products?page=1&limit=10",
        search: "GET /products?search=laptop"
      }
    })
  end
end

# Health check endpoint
server.mount_proc "/health" do |req, res|
  apply_middleware(req, res) do
    health_data = {
      status: "healthy",
      timestamp: Time.now.iso8601,
      uptime: Time.now - $start_time,
      version: "1.0.0",
      memory_usage: `ps -o rss= -p #{Process.pid}`.to_i,
      active_products: $db.count_products,
      database: "connected"
    }
    send_json_response(res, health_data)
  end
end

# Metrics endpoint
server.mount_proc "/metrics" do |req, res|
  apply_middleware(req, res) do
    metrics = $db.get_api_stats
    metrics.merge!({
      uptime_seconds: Time.now - $start_time,
      memory_usage_mb: `ps -o rss= -p #{Process.pid}`.to_i / 1024,
      active_connections: 1, # Could be enhanced with connection tracking
      rate_limit_config: {
        max_requests_per_minute: 100,
        window_seconds: 60
      }
    })
    send_json_response(res, metrics)
  end
end

# Authentication endpoints
server.mount_proc "/auth/register" do |req, res|
  apply_middleware(req, res) do
    if req.request_method == "POST"
      data = parse_body(req)
      
      # Validate required fields
      errors = []
      errors << "Username required" if data["username"].nil? || data["username"].strip.empty?
      errors << "Email required" if data["email"].nil? || data["email"].strip.empty?
      errors << "Password required (min 6 chars)" if data["password"].nil? || data["password"].length < 6
      
      if errors.any?
        send_json_response(res, { errors: errors }, 400)
        next
      end
      
      # Hash password and create user
      password_hash = AuthManager.hash_password(data["password"])
      result = $db.create_user(
        Sanitizer.clean_string(data["username"]),
        Sanitizer.clean_string(data["email"]),
        password_hash
      )
      
      send_json_response(res, {
        message: "User registered successfully",
        api_key: result[:api_key]
      }, 201)
    else
      send_json_response(res, { error: "Method Not Allowed" }, 405)
    end
  end
end

# File upload endpoint
server.mount_proc "/upload" do |req, res|
  apply_middleware(req, res) do
    if req.request_method == "POST"
      # Require authentication
      user = require_auth(req, res)
      return unless user
      
      # Handle file upload
      upload_result = FileUploadManager.upload_file(req, res)
      
      if upload_result[:error]
        send_json_response(res, { error: upload_result[:error] }, 400)
      else
        send_json_response(res, {
          message: "File uploaded successfully",
          file: upload_result
        }, 201)
      end
    else
      send_json_response(res, { error: "Method Not Allowed" }, 405)
    end
  end
end

# GET /products -> list all products with pagination and search
server.mount_proc "/products" do |req, res|
  apply_middleware(req, res) do
    if req.request_method == "OPTIONS"
      send_json_response(res, "", 200)
      next
    end

    if req.request_method == "GET"
      # Get pagination parameters
      page = (req.query["page"] || 1).to_i
      limit = [(req.query["limit"] || 10).to_i, 100].min
      offset = (page - 1) * limit
      search = req.query["search"]
      
      # Get products from database
      products = $db.get_all_products(limit, offset, search)
      total = $db.count_products(search)
      
      response_data = {
        products: products,
        pagination: {
          current_page: page,
          total_items: total,
          total_pages: (total.to_f / limit).ceil,
          items_per_page: limit
        }
      }
      
      send_json_response(res, response_data)

    elsif req.request_method == "POST"
      # Require authentication for POST
      user = require_auth(req, res)
      return unless user
      
      data = parse_body(req)
      
      # Validate input
      errors = validate_product_data(data, ["name", "price"])
      if errors.any?
        send_json_response(res, { errors: errors }, 400)
        next
      end

      # Sanitize input and create product
      sanitized = sanitize_product_data(data)
      product = $db.create_product(
        sanitized[:name],
        sanitized[:price],
        sanitized[:category],
        data["image_url"],
        data["stock"] || 0
      )

      send_json_response(res, product, 201)
    else
      send_json_response(res, { error: "Method Not Allowed" }, 405)
    end
  end
end

# Routes with ID: /product?id=:id
server.mount_proc "/product" do |req, res|
  apply_middleware(req, res) do
    if req.request_method == "OPTIONS"
      send_json_response(res, "", 200)
      next
    end

    id = req.query["id"]&.to_i
    
    if id.nil? || id <= 0
      send_json_response(res, { error: "Valid product ID is required" }, 400)
      next
    end
    
    product = $db.get_product(id)

    if product.nil?
      send_json_response(res, { error: "Product not found" }, 404)
      next
    end

    case req.request_method
    when "GET"
      send_json_response(res, product)

    when "PUT"
      # Require authentication for PUT
      user = require_auth(req, res)
      return unless user
      
      data = parse_body(req)
      
      # Validate update data
      if data.any?
        errors = validate_product_data(data, []) # No required fields for updates
        if errors.any?
          send_json_response(res, { errors: errors }, 400)
          next
        end
      end
      
      # Sanitize and update product
      sanitized = sanitize_product_data(data)
      updated_product = $db.update_product(
        id,
        name: sanitized[:name],
        price: sanitized[:price],
        category: sanitized[:category],
        image_url: data["image_url"],
        stock: data["stock"]
      )
      
      send_json_response(res, updated_product)

    when "DELETE"
      # Require authentication for DELETE
      user = require_auth(req, res)
      return unless user
      
      deleted_product = $db.delete_product(id)
      send_json_response(res, { message: "Product deleted successfully" })

    else
      send_json_response(res, { error: "Method Not Allowed" }, 405)
    end
  end
end

# Reviews endpoints
server.mount_proc "/reviews" do |req, res|
  apply_middleware(req, res) do
    if req.request_method == "OPTIONS"
      send_json_response(res, "", 200)
      next
    end

    if req.request_method == "POST"
      # Require authentication
      user = require_auth(req, res)
      return unless user
      
      data = parse_body(req)
      
      # Validate required fields
      errors = []
      errors << "Product ID required" if data["product_id"].nil?
      errors << "Rating required (1-5)" if data["rating"].nil? || !(1..5).include?(data["rating"].to_i)
      
      if errors.any?
        send_json_response(res, { errors: errors }, 400)
        next
      end
      
      # Create review
      review = $db.create_review(
        data["product_id"].to_i,
        user["id"],
        data["rating"].to_i,
        data["comment"]
      )
      
      send_json_response(res, review, 201)
    else
      send_json_response(res, { error: "Method Not Allowed" }, 405)
    end
  end
end

# Product-specific reviews
server.mount_proc "/product/reviews" do |req, res|
  apply_middleware(req, res) do
    if req.request_method == "GET"
      product_id = req.query["product_id"]&.to_i
      
      if product_id.nil? || product_id <= 0
        send_json_response(res, { error: "Valid product ID required" }, 400)
        next
      end
      
      # Get reviews and rating summary
      reviews = $db.get_product_reviews(product_id)
      rating_summary = $db.get_product_rating_summary(product_id)
      
      send_json_response(res, {
        product_id: product_id,
        rating_summary: rating_summary,
        reviews: reviews
      })
    else
      send_json_response(res, { error: "Method Not Allowed" }, 405)
    end
  end
end

trap("INT") { server.shutdown }

puts "Ruby server running on http://localhost:3000"
server.start

