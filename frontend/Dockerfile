# React Frontend Dockerfile
# Multi-stage build for optimized image size
# Trigger build for GitHub Container Registry

# Build stage
FROM node:18-alpine AS builder

WORKDIR /app

# Copy package files
COPY frontend/package*.json ./

# Install dependencies
RUN npm ci

# Copy source code
COPY frontend/ ./

# Set API base URL for production deployment
# Use relative path to work with ingress routing at /comsa-dashboard/api
ENV VITE_API_BASE_URL=/comsa-dashboard/api

# Build for production
RUN npm run build

# Production stage
FROM nginx:alpine

# Create necessary directories with correct permissions
RUN mkdir -p /var/cache/nginx /var/run /tmp && \
    chown -R nginx:nginx /var/cache/nginx /var/run /tmp && \
    chown -R nginx:nginx /usr/share/nginx/html

# Copy built files (Vite outputs to dist/ by default)
COPY --from=builder --chown=nginx:nginx /app/dist /usr/share/nginx/html

# Copy nginx configuration for React Router
COPY <<EOF /etc/nginx/conf.d/default.conf
server {
    listen 8080;
    server_name _;
    root /usr/share/nginx/html;
    index index.html;

    # React Router support
    location / {
        try_files \$uri \$uri/ /index.html;
    }

    # API proxy (optional - if not using ingress routing)
    location /api {
        proxy_pass http://comsa-backend:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF

# Switch to nginx user
USER nginx

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]
