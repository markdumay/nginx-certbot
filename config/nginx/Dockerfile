# Pull base image
FROM nginx:alpine 

# Copy default nginx configuration and web page
COPY ./nginx.conf /etc/nginx/nginx.conf
COPY ./ffdhe2048.txt /etc/nginx/snippets/ffdhe2048.txt
COPY ./index.html /var/www/html/index.html 
COPY ./docker-entrypoint.sh /docker-entrypoint.sh

# Assign access rights for key files and folders
RUN addgroup -g 1001 -S www && adduser --uid 1001 -S www -G www && \
    touch /var/run/nginx.pid && \ 
    mkdir -p /etc/letsencrypt && \
    mkdir -p /var/www/html && \
    chown -R www:www /etc/nginx/conf.d && \
    chown -R www:www /etc/letsencrypt && \
    chown -R www:www /var/www/html && \
    chown -R www:www /var/run/nginx.pid && \ 
    chown -R www:www /var/cache/nginx && \
    chmod +x /docker-entrypoint.sh

# Define mountable directories (shared with certbot)
VOLUME /etc/letsencrypt

# Run the container as non-root user www
USER www

# Call entrypoint of parent image
ENTRYPOINT ["/docker-entrypoint.sh", "nginx"]

# Expose http and https ports (ports below 1024 are restricted to root only)
EXPOSE 4430 8080