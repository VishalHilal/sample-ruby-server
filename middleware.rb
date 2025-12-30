# Rate limiting middleware
class RateLimiter
  def initialize(max_requests = 100, window_seconds = 60)
    @max_requests = max_requests
    @window_seconds = window_seconds
    @requests = {}
    @failed_auths = {}
  end
  
  def allow_request?(ip)
    now = Time.now
    
    # Check if IP is blocked due to auth failures
    if @failed_auths[ip] && @failed_auths[ip][:count] >= 5
      block_time = @failed_auths[ip][:blocked_until]
      if now < block_time
        return false # Still blocked
      else
        @failed_auths.delete(ip) # Unblock
      end
    end
    
    # Remove old requests outside the window
    @requests[ip] ||= []
    @requests[ip] = @requests[ip].select { |time| now - time < @window_seconds }
    
    if @requests[ip].length < @max_requests
      @requests[ip] << now
      true
    else
      false
    end
  end
  
  def record_auth_failure(ip)
    @failed_auths[ip] ||= { count: 0, blocked_until: nil }
    @failed_auths[ip][:count] += 1
    
    if @failed_auths[ip][:count] >= 5
      @failed_auths[ip][:blocked_until] = Time.now + 900 # Block for 15 minutes
    end
  end
end

# Input sanitization
module Sanitizer
  def self.clean_string(input)
    return "" if input.nil? || input.empty?
    
    # Remove HTML tags and special characters
    input.to_s.gsub(/<[^>]*>/, '').strip.gsub(/[<>'"&]/, '')
  end
  
  def self.clean_price(input)
    return 0.0 if input.nil?
    
    # Only allow numbers and decimal point
    price_str = input.to_s.gsub(/[^0-9.]/, '')
    price_str.to_f
  end
end

# Request logger
module RequestLogger
  def self.log_request(req, res, start_time)
    duration = ((Time.now - start_time) * 1000).round(2)
    
    log_entry = {
      timestamp: Time.now.iso8601,
      method: req.request_method,
      path: req.path,
      query: req.query,
      ip: req.remote_ip,
      status: res.status,
      duration_ms: duration,
      user_agent: req['User-Agent']
    }
    
    puts "[#{log_entry[:timestamp]}] #{log_entry[:method]} #{log_entry[:path]} - #{log_entry[:status]} (#{log_entry[:duration_ms]}ms)"
  end
end

# Initialize rate limiter
$rate_limiter = RateLimiter.new(100, 60) # 100 requests per minute per IP
