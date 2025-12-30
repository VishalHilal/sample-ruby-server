require "fileutils"
require "base64"

class FileUploadManager
  UPLOAD_DIR = File.join(Dir.pwd, "public", "uploads")
  ALLOWED_TYPES = %w[image/jpeg image/png image/gif image/webp]
  MAX_FILE_SIZE = 5 * 1024 * 1024 # 5MB
  
  def self.ensure_upload_dir
    FileUtils.mkdir_p(UPLOAD_DIR) unless Dir.exist?(UPLOAD_DIR)
  end
  
  def self.upload_file(req, res)
    ensure_upload_dir
    
    content_type = req["Content-Type"]
    content_length = req["Content-Length"].to_i
    
    # Validate file size
    if content_length > MAX_FILE_SIZE
      return { error: "File too large. Maximum size is 5MB" }
    end
    
    # Validate content type
    unless ALLOWED_TYPES.include?(content_type)
      return { error: "Invalid file type. Only JPEG, PNG, GIF, and WebP allowed" }
    end
    
    # Generate unique filename
    filename = "#{Time.now.to_i}_#{rand(1000)}.#{extension_from_type(content_type)}"
    file_path = File.join(UPLOAD_DIR, filename)
    
    # Write file
    File.open(file_path, "wb") do |file|
      file.write(req.body)
    end
    
    # Return file info
    {
      filename: filename,
      path: "/uploads/#{filename}",
      size: content_length,
      type: content_type
    }
  end
  
  def self.delete_file(filename)
    file_path = File.join(UPLOAD_DIR, filename)
    if File.exist?(file_path)
      File.delete(file_path)
      true
    else
      false
    end
  end
  
  def self.get_file_url(filename)
    "/uploads/#{filename}"
  end
  
  private
  
  def self.extension_from_type(content_type)
    case content_type
    when "image/jpeg" then "jpg"
    when "image/png" then "png"
    when "image/gif" then "gif"
    when "image/webp" then "webp"
    else "bin"
    end
  end
end
