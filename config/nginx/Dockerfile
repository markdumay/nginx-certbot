# Copyright © 2021 Mark Dumay. All rights reserved.
# Use of this source code is governed by The MIT License (MIT) that can be found in the LICENSE file.

#======================================================================================================================
# Build arguments
#======================================================================================================================
ARG UID=1001
ARG GID=1001
ARG BUILD_USER='www'
ARG BUILD_FLAG=''
ARG BUILD_VERSION


#======================================================================================================================
# Main image
#======================================================================================================================
FROM nginx:1.19.6-alpine

ARG BUILD_VERSION
ENV BUILD_VERSION "${BUILD_VERSION}"

# Copy default nginx configuration and web page
COPY ./dbm/utils/harden_alpine.sh /usr/local/sbin/harden_alpine.sh
COPY ./config/nginx/docker-entrypoint.sh /docker-entrypoint.sh
COPY ./config/nginx/nginx.conf /etc/nginx/nginx.conf
COPY ./config/nginx/ffdhe2048.txt /etc/nginx/snippets/ffdhe2048.txt
COPY ./config/nginx/templates /etc/nginx/templates
COPY ./config/nginx/index.html /var/www/html/index.html 

# Update grep package and assign access rights for key files and folders
# Note: shadow package is needed to support higher UIDs/GIDsARG UID
ARG UID
ARG GID
ARG BUILD_USER
ARG BUILD_FLAG
RUN apk update -f && \
    apk --no-cache add -f shadow && \
    rm -rf /var/cache/apk/* && \
    touch /var/run/nginx.pid && \ 
    mkdir -p /etc/letsencrypt && \
    mkdir -p /var/www/html && \
    chmod +x /docker-entrypoint.sh && \
    chmod +x /usr/local/sbin/harden_alpine.sh && \
    /usr/local/sbin/harden_alpine.sh harden \
        -n "${BUILD_USER}" \
        -u "${UID}" \
        -g "${GID}" \
        -d /etc/nginx/conf.d \
        -d /etc/nginx/snippets \
        -d /etc/letsencrypt \
        -d /var/www/html \
        -d /var/run/nginx.pid \
        -d /var/cache/nginx \
        -d /tmp \
        "${BUILD_FLAG}" && \
    rm -f /usr/local/sbin/harden_alpine.sh

# Define mountable directories (shared with certbot and other containers)
VOLUME /etc/letsencrypt, /etc/nginx/templates

# Run the container as non-root user
ARG BUILD_USER
USER "${BUILD_USER}"

# Call entrypoint of parent image
ENTRYPOINT ["/docker-entrypoint.sh", "nginx"]

# Expose https and http ports (ports below 1024 are restricted to root only)
EXPOSE 4430 8080