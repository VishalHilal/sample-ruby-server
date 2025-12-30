require "sqlite3"
require "json"

class Database
  def initialize(db_path = nil)
    db_path ||= File.join(Dir.pwd, "data", "products.db")
    @db = SQLite3::Database.new(db_path)
    @db.results_as_hash = true
    setup_tables
  end
  
  def setup_tables
    @db.execute <<-SQL
      CREATE TABLE IF NOT EXISTS products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        price REAL NOT NULL,
        category TEXT,
        image_url TEXT,
        stock INTEGER DEFAULT 0,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    SQL
    
    @db.execute <<-SQL
      CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE NOT NULL,
        email TEXT UNIQUE NOT NULL,
        password_hash TEXT NOT NULL,
        api_key TEXT UNIQUE,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    SQL
    
    @db.execute <<-SQL
      CREATE TABLE IF NOT EXISTS reviews (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        user_id INTEGER,
        rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
        comment TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
      )
    SQL
    
    @db.execute <<-SQL
      CREATE TABLE IF NOT EXISTS api_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        method TEXT NOT NULL,
        path TEXT NOT NULL,
        status_code INTEGER NOT NULL,
        response_time_ms REAL,
        ip_address TEXT,
        user_agent TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    SQL
  end
  
  # Product operations
  def create_product(name, price, category = nil, image_url = nil, stock = 0)
    @db.execute(
      "INSERT INTO products (name, price, category, image_url, stock) VALUES (?, ?, ?, ?, ?)",
      [name, price, category, image_url, stock]
    )
    get_product(@db.last_insert_rowid)
  end
  
  def get_product(id)
    result = @db.execute("SELECT * FROM products WHERE id = ?", [id])
    result.first
  end
  
  def get_all_products(limit = 100, offset = 0, search = nil)
    query = "SELECT * FROM products"
    params = []
    
    if search
      query += " WHERE name LIKE ? OR category LIKE ?"
      params = ["%#{search}%", "%#{search}%"]
    end
    
    query += " ORDER BY created_at DESC LIMIT ? OFFSET ?"
    params += [limit, offset]
    
    @db.execute(query, params)
  end
  
  def update_product(id, name: nil, price: nil, category: nil, image_url: nil, stock: nil)
    updates = []
    params = []
    
    if name
      updates << "name = ?"
      params << name
    end
    
    if price
      updates << "price = ?"
      params << price
    end
    
    if category
      updates << "category = ?"
      params << category
    end
    
    if image_url
      updates << "image_url = ?"
      params << image_url
    end
    
    if stock
      updates << "stock = ?"
      params << stock
    end
    
    return nil if updates.empty?
    
    updates << "updated_at = CURRENT_TIMESTAMP"
    params << id
    
    @db.execute("UPDATE products SET #{updates.join(', ')} WHERE id = ?", params)
    get_product(id)
  end
  
  def delete_product(id)
    product = get_product(id)
    @db.execute("DELETE FROM products WHERE id = ?", [id])
    product
  end
  
  def count_products(search = nil)
    if search
      @db.execute(
        "SELECT COUNT(*) as count FROM products WHERE name LIKE ? OR category LIKE ?",
        ["%#{search}%", "%#{search}%"]
      ).first["count"]
    else
      @db.execute("SELECT COUNT(*) as count FROM products").first["count"]
    end
  end
  
  # User operations
  def create_user(username, email, password_hash)
    api_key = generate_api_key
    @db.execute(
      "INSERT INTO users (username, email, password_hash, api_key) VALUES (?, ?, ?, ?)",
      [username, email, password_hash, api_key]
    )
    { api_key: api_key }
  end
  
  def find_user_by_api_key(api_key)
    result = @db.execute("SELECT * FROM users WHERE api_key = ?", [api_key])
    result.first
  end
  
  # Logging operations
  def log_request(method, path, status_code, response_time, ip_address, user_agent)
    @db.execute(
      "INSERT INTO api_logs (method, path, status_code, response_time_ms, ip_address, user_agent) VALUES (?, ?, ?, ?, ?, ?)",
      [method, path, status_code, response_time, ip_address, user_agent]
    )
  end
  
  def get_api_stats
    {
      total_requests: @db.execute("SELECT COUNT(*) as count FROM api_logs").first["count"],
      avg_response_time: @db.execute("SELECT AVG(response_time_ms) as avg FROM api_logs").first["avg"],
      requests_today: @db.execute("SELECT COUNT(*) as count FROM api_logs WHERE DATE(created_at) = DATE('now')").first["count"],
      error_rate: @db.execute("SELECT (COUNT(*) * 100.0 / (SELECT COUNT(*) FROM api_logs)) as rate FROM api_logs WHERE status_code >= 400").first["rate"]
    }
  end
  
  # Review operations
  def create_review(product_id, user_id, rating, comment = nil)
    @db.execute(
      "INSERT INTO reviews (product_id, user_id, rating, comment) VALUES (?, ?, ?, ?)",
      [product_id, user_id, rating, comment]
    )
    get_review(@db.last_insert_rowid)
  end
  
  def get_review(id)
    result = @db.execute(
      "SELECT r.*, u.username, p.name as product_name FROM reviews r 
       LEFT JOIN users u ON r.user_id = u.id 
       LEFT JOIN products p ON r.product_id = p.id 
       WHERE r.id = ?", 
      [id]
    )
    result.first
  end
  
  def get_product_reviews(product_id, limit = 50, offset = 0)
    @db.execute(
      "SELECT r.*, u.username FROM reviews r 
       LEFT JOIN users u ON r.user_id = u.id 
       WHERE r.product_id = ? 
       ORDER BY r.created_at DESC 
       LIMIT ? OFFSET ?", 
      [product_id, limit, offset]
    )
  end
  
  def get_product_rating_summary(product_id)
    result = @db.execute(
      "SELECT COUNT(*) as total_reviews, AVG(rating) as avg_rating 
       FROM reviews WHERE product_id = ?", 
      [product_id]
    ).first
    
    if result["total_reviews"] > 0
      {
        total_reviews: result["total_reviews"],
        average_rating: result["avg_rating"].round(2)
      }
    else
      { total_reviews: 0, average_rating: 0 }
    end
  end
  
  def update_review(id, rating: nil, comment: nil)
    updates = []
    params = []
    
    if rating
      updates << "rating = ?"
      params << rating
    end
    
    if comment
      updates << "comment = ?"
      params << comment
    end
    
    return nil if updates.empty?
    
    params << id
    @db.execute("UPDATE reviews SET #{updates.join(', ')} WHERE id = ?", params)
    get_review(id)
  end
  
  def delete_review(id)
    review = get_review(id)
    @db.execute("DELETE FROM reviews WHERE id = ?", [id])
    review
  end
  
  private
  
  def generate_api_key
    "rk_" + Array.new(32) { rand(36).to_s(36) }.join
  end
end
