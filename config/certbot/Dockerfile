# Copyright © 2021 Mark Dumay. All rights reserved.
# Use of this source code is governed by The MIT License (MIT) that can be found in the LICENSE file.

#======================================================================================================================
# Build arguments
#======================================================================================================================
ARG CERTBOT_DNS_PLUGIN
ARG BUILD_UID=1001
ARG BUILD_GID=1001
ARG BUILD_USER='certbot'
ARG BUILD_FLAGS=''
ARG BUILD_VERSION
ARG BUILD_TARGET='test'
ARG CERTBOT_VERSION

#======================================================================================================================
# Main image
#======================================================================================================================
# Pull base image for specified DNS plugin
FROM certbot/dns-"${CERTBOT_DNS_PLUGIN}":v"${CERTBOT_VERSION}"

ARG BUILD_VERSION
ENV BUILD_VERSION "${BUILD_VERSION}"

# Copy helper scripts
COPY ./dbm/utils/harden_alpine.sh /usr/local/sbin/harden_alpine.sh
COPY ./config/certbot/certbot_issue.sh /usr/local/sbin/certbot_issue.sh
COPY ./config/certbot/docker_entrypoint.sh /usr/local/sbin/docker_entrypoint.sh

# Harden the image and assign access rights for key files and folders
# Note: chmod is needed by certbot_issue.sh
ARG BUILD_UID
ARG BUILD_GID
ARG BUILD_USER
ARG BUILD_FLAGS
ARG CERTBOT_DNS_PLUGIN

RUN apk update -f && \
    apk --no-cache add -f grep shadow && \
    rm -rf /var/cache/apk/* /tmp && \
    chmod +x /usr/local/sbin/certbot_issue.sh && \
    chmod +x /usr/local/sbin/docker_entrypoint.sh && \
    chmod +x /usr/local/sbin/harden_alpine.sh && \
    /usr/local/sbin/harden_alpine.sh harden \
        -n "${BUILD_USER}" \
        -u "${BUILD_UID}" \
        -g "${BUILD_GID}" \
        -v /etc/certbot \
        -d "/home/${BUILD_USER}" \
        -d /tmp \
        -d /var/lib/certbot \
        -d /var/log/certbot \
        -f /usr/local/sbin/certbot_issue.sh \
        -f /usr/local/sbin/docker_entrypoint.sh \
        -k chmod \
        "${BUILD_FLAGS}" && \
    rm -f /usr/local/sbin/harden_alpine.sh

# Run the container as non-root user
ARG BUILD_USER
USER "${BUILD_USER}"

# Expose the certificates folder as volume
VOLUME [ "/etc/certbot" ]

# Define the healthcheck (production only)
ARG BUILD_TARGET
HEALTHCHECK --interval=1m30s --timeout=10s --retries=3 --start-period=1m \
    CMD if [[ "${BUILD_TARGET}" == 'production' ]]; then certbot_issue.sh verify; else exit 0; fi

# Run certbot script (repeats every 12 hours)
ENTRYPOINT [ "docker_entrypoint.sh" ]