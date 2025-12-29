require "webrick"
require "json"

server = WEBrick::HTTPServer.new(
  Port: 3000
)

# In-memory "database"
$products = []
$next_id = 1

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

# Helper to send JSON response
def send_json_response(res, data, status = 200)
  res.status = status
  res["Content-Type"] = "application/json"
  set_cors_headers(res)
  res.body = data.is_a?(String) ? data : JSON.pretty_generate(data)
end

# Root route
server.mount_proc "/" do |req, res|
  send_json_response(res, {
    message: "Ruby Business App API Running",
    endpoints: {
      "GET /" => "API information",
      "GET /products" => "List all products (supports pagination and search)",
      "POST /products" => "Create a new product",
      "GET /product?id=:id" => "Get a specific product",
      "PUT /product?id=:id" => "Update a specific product",
      "DELETE /product?id=:id" => "Delete a specific product"
    },
    examples: {
      create_product: { name: "Example Product", price: "29.99", category: "electronics" },
      pagination: "GET /products?page=1&limit=10",
      search: "GET /products?search=laptop"
    }
  })
end

# GET /products -> list all products with pagination and search
server.mount_proc "/products" do |req, res|
  if req.request_method == "OPTIONS"
    send_json_response(res, "", 200)
    next
  end

  if req.request_method == "GET"
    filtered_products = $products.dup
    
    # Search functionality
    if req.query["search"]
      search_term = req.query["search"].downcase
      filtered_products = filtered_products.select do |product|
        product[:name].downcase.include?(search_term) || 
        (product[:category] && product[:category].downcase.include?(search_term))
      end
    end
    
    # Pagination
    page = (req.query["page"] || 1).to_i
    limit = [(req.query["limit"] || 10).to_i, 100].min # Max 100 items
    offset = (page - 1) * limit
    
    total = filtered_products.length
    paginated_products = filtered_products[offset, limit] || []
    
    response_data = {
      products: paginated_products,
      pagination: {
        current_page: page,
        total_items: total,
        total_pages: (total.to_f / limit).ceil,
        items_per_page: limit
      }
    }
    
    send_json_response(res, response_data)

  elsif req.request_method == "POST"
    data = parse_body(req)
    
    # Validate input
    errors = validate_product_data(data, ["name", "price"])
    if errors.any?
      send_json_response(res, { errors: errors }, 400)
      next
    end

    product = {
      id: $next_id,
      name: data["name"].strip,
      price: data["price"].to_f,
      category: data["category"]&.strip
    }

    $products << product
    $next_id += 1

    send_json_response(res, product, 201)
  else
    send_json_response(res, { error: "Method Not Allowed" }, 405)
  end
end

# Routes with ID: /product?id=:id
server.mount_proc "/product" do |req, res|
  if req.request_method == "OPTIONS"
    send_json_response(res, "", 200)
    next
  end

  id = req.query["id"]&.to_i
  
  if id.nil? || id <= 0
    send_json_response(res, { error: "Valid product ID is required" }, 400)
    next
  end
  
  product = $products.find { |p| p[:id] == id }

  if product.nil?
    send_json_response(res, { error: "Product not found" }, 404)
    next
  end

  case req.request_method
  when "GET"
    send_json_response(res, product)

  when "PUT"
    data = parse_body(req)
    
    # Validate update data
    if data.any?
      errors = validate_product_data(data, []) # No required fields for updates
      if errors.any?
        send_json_response(res, { errors: errors }, 400)
        next
      end
    end
    
    # Update fields if provided
    product[:name] = data["name"].strip if data["name"] && !data["name"].strip.empty?
    product[:price] = data["price"].to_f if data["price"]
    product[:category] = data["category"]&.strip if data["category"]
    
    send_json_response(res, product)

  when "DELETE"
    $products.delete(product)
    send_json_response(res, { message: "Product deleted successfully" })

  else
    send_json_response(res, { error: "Method Not Allowed" }, 405)
  end
end

trap("INT") { server.shutdown }

puts "Ruby server running on http://localhost:3000"
server.start

