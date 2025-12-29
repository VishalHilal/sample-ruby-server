# Rate limiting middleware
class RateLimiter
  def initialize(max_requests = 100, window_seconds = 60)
    @max_requests = max_requests
    @window_seconds = window_seconds
    @requests = {}
  end
  
  def allow_request?(ip)
    now = Time.now
    @requests[ip] ||= []
    
    # Remove old requests outside the window
    @requests[ip] = @requests[ip].select { |time| now - time < @window_seconds }
    
    if @requests[ip].length < @max_requests
      @requests[ip] << now
      true
    else
      false
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
