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
rescue
  {}
end

# Root route
server.mount_proc "/" do |req, res|
  res.body = "Ruby Business App API Running"
end

# GET /products -> list all products
server.mount_proc "/products" do |req, res|
  res["Content-Type"] = "application/json"

  if req.request_method == "GET"
    res.body = JSON.pretty_generate($products)

  elsif req.request_method == "POST"
    data = parse_body(req)

    product = {
      id: $next_id,
      name: data["name"],
      price: data["price"]
    }

    $products << product
    $next_id += 1

    res.status = 201
    res.body = JSON.pretty_generate(product)
  else
    res.status = 405
    res.body = "Method Not Allowed"
  end
end

# Routes with ID: /products/:id
server.mount_proc "/product" do |req, res|
  res["Content-Type"] = "application/json"

  id = req.query["id"]&.to_i
  product = $products.find { |p| p[:id] == id }

  if product.nil?
    res.status = 404
    res.body = { error: "Product not found" }.to_json
    next
  end

  case req.request_method
  when "GET"
    res.body = JSON.pretty_generate(product)

  when "PUT"
    data = parse_body(req)
    product[:name] = data["name"] if data["name"]
    product[:price] = data["price"] if data["price"]
    res.body = JSON.pretty_generate(product)

  when "DELETE"
    $products.delete(product)
    res.body = { message: "Product deleted" }.to_json

  else
    res.status = 405
    res.body = "Method Not Allowed"
  end
end

trap("INT") { server.shutdown }

puts "Ruby server running on http://localhost:3000"
server.start

