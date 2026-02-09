# Stage 1: Build the Flutter web application
FROM ghcr.io/cirruslabs/flutter:stable AS build-env

# Set working directory
WORKDIR /app

# Copy the project files
COPY . .

# Get dependencies
RUN flutter pub get

# Build the web application
RUN flutter build web --release

# Stage 2: Serve the application with Nginx
FROM nginx:1.25-alpine

# Copy the built web files from the previous stage
COPY --from=build-env /app/build/web /usr/share/nginx/html

# Copy custom Nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Expose port 80
EXPOSE 80

# Start Nginx
CMD ["nginx", "-g", "daemon off;"]
