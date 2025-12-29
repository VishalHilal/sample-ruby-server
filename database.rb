require "sqlite3"
require "json"

class Database
  def initialize(db_path = "products.db")
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
  def create_product(name, price, category = nil)
    @db.execute(
      "INSERT INTO products (name, price, category) VALUES (?, ?, ?)",
      [name, price, category]
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
  
  def update_product(id, name: nil, price: nil, category: nil)
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
  
  private
  
  def generate_api_key
    "rk_" + Array.new(32) { rand(36).to_s(36) }.join
  end
end
