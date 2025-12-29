require "bcrypt"

class AuthManager
  def self.hash_password(password)
    BCrypt::Password.create(password)
  end
  
  def self.verify_password(password, hash)
    BCrypt::Password.new(hash) == password
  end
  
  def self.generate_token(user_id)
    payload = {
      user_id: user_id,
      exp: Time.now.to_i + 3600, # 1 hour expiration
      iat: Time.now.to_i
    }
    
    # Simple token generation (in production, use proper JWT library)
    token_data = payload.to_json
    Base64.strict_encode64(token_data + "." + generate_signature(token_data))
  end
  
  def self.verify_token(token)
    return nil unless token
    
    begin
      decoded = Base64.strict_decode64(token)
      token_data, signature = decoded.split(".")
      
      # Verify signature
      expected_signature = generate_signature(token_data)
      return nil unless signature == expected_signature
      
      payload = JSON.parse(token_data)
      
      # Check expiration
      return nil if payload["exp"] < Time.now.to_i
      
      payload
    rescue
      nil
    end
  end
  
  def self.authenticate_request(req, db)
    # Try API key first
    api_key = req["Authorization"]&.gsub("Bearer ", "")
    if api_key && api_key.start_with?("rk_")
      user = db.find_user_by_api_key(api_key)
      return user if user
    end
    
    # Try JWT token
    token = req["X-API-Token"] || req["Authorization"]&.gsub("Bearer ", "")
    if token
      payload = verify_token(token)
      return { id: payload["user_id"] } if payload
    end
    
    nil
  end
  
  private
  
  def self.generate_signature(data)
    # Simple HMAC-like signature (in production, use proper HMAC with secret key)
    Digest::SHA256.hexdigest(data + "secret_key")[0, 32]
  end
end
