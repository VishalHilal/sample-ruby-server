FROM ruby:3.0-alpine

WORKDIR /app

# Copy gem files
COPY server.rb middleware.rb ./

# Install any needed gems (none for this simple server)
RUN gem install webrick json

# Expose port
EXPOSE 3000

# Run the server
CMD ["ruby", "server.rb"]
