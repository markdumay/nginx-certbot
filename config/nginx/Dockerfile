# Copyright © 2021 Mark Dumay. All rights reserved.
# Use of this source code is governed by The MIT License (MIT) that can be found in the LICENSE file.

#======================================================================================================================
# Build arguments
#======================================================================================================================
ARG BUILD_UID=1001
ARG BUILD_GID=1001
ARG BUILD_USER='www'
ARG BUILD_FLAGS=''
ARG BUILD_VERSION
ARG BUILD_TARGET='test'
ARG NGINX_VERSION


#======================================================================================================================
# Main image
#======================================================================================================================
FROM nginx:"${NGINX_VERSION}"-alpine

ARG BUILD_VERSION
ENV BUILD_VERSION "${BUILD_VERSION}"

# Copy helper scripts and default nginx configuration
COPY ./dbm/utils/harden_alpine.sh /usr/local/sbin/harden_alpine.sh
COPY ./config/nginx/docker_entrypoint.sh /usr/local/sbin/docker_entrypoint.sh
COPY ./config/nginx/nginx.conf /etc/nginx/nginx.conf
COPY ./config/nginx/ffdhe2048.txt /etc/nginx/snippets/ffdhe2048.txt
COPY ./config/nginx/templates /etc/nginx/templates
COPY ./config/nginx/index.html /var/www/html/index.html 

# Harden the image and assign access rights for key files and folders
ARG BUILD_UID
ARG BUILD_GID
ARG BUILD_USER
ARG BUILD_FLAGS
ARG BUILD_TARGET
RUN apk update -f && \
    apk --no-cache add -f shadow && \
    rm -rf /var/cache/apk/* /var/cache/nginx /tmp && \
    chmod +x /usr/local/sbin/docker_entrypoint.sh && \
    chmod +x /usr/local/sbin/harden_alpine.sh && \
    /usr/local/sbin/harden_alpine.sh harden \
        -U nginx \
        -n "${BUILD_USER}" \
        -u "${BUILD_UID}" \
        -g "${BUILD_GID}" \
        -v /etc/letsencrypt \
        -v /etc/nginx/templates \
        -d /tmp \
        -d /var/lib/nginx/conf.d \
        -d /var/cache/nginx \
        # -d /etc/nginx/snippets \
        -f /usr/local/sbin/docker_entrypoint.sh \
        -f /etc/nginx/nginx.conf \
        -f /etc/nginx/snippets/ffdhe2048.txt \
        -f /var/www/html/index.html \
        -k nginx \
        "${BUILD_FLAGS}" && \
    rm -f /usr/local/sbin/harden_alpine.sh 

# Run the container as non-root user
USER "${BUILD_USER}"

# Define mountable directories (shared with certbot and other containers)
VOLUME [ "/etc/letsencrypt", "/etc/nginx/templates" ]

# Define the healthcheck (production only)
ARG BUILD_TARGET
HEALTHCHECK --interval=1m30s --timeout=10s --retries=3 --start-period=1m \
    CMD if [[ "${BUILD_TARGET}" == 'production' ]]; then curl --fail "localhost:${NGINX_PORT_HTTP}"; else exit 0; fi

# Start custom script:
#  - configure nginx using templates
#  - wait for cerficates
#  - run nginx daemon in foreground
#  - monitor for template changes, and reload if needed
ENTRYPOINT [ "docker_entrypoint.sh", "nginx" ]

# Expose https and http ports (ports below 1024 are restricted to root only)
EXPOSE 4430 8080