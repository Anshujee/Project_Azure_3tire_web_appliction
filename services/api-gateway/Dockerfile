# NGINX has no build step — just copy the config into the official image
FROM nginxinc/nginx-unprivileged:1.27-alpine

# Remove default NGINX config
RUN rm /etc/nginx/conf.d/default.conf

# Copy our custom config
COPY nginx.conf /etc/nginx/nginx.conf

# NGINX runs as root by default — not ideal but standard for NGINX containers
# Port 8080 (not 80) so we could run as non-root if needed in future
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD wget -q -O- http://localhost:8080/health || exit 1

CMD ["nginx", "-g", "daemon off;"]
