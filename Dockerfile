FROM ruby:3.0-alpine

# Install development tools and dependencies
RUN apk add --no-cache \
    build-base \
    sqlite-dev \
    gcc \
    musl-dev \
    linux-headers \
    wget

WORKDIR /app

# Copy Gemfile and install gems
COPY Gemfile ./
RUN bundle config set --local without 'development test' && \
    bundle install

# Copy all Ruby files
COPY *.rb ./

# Expose port
EXPOSE 3000

# Create database directory
RUN mkdir -p /app/data

# Run the server
CMD ["ruby", "server.rb"]
