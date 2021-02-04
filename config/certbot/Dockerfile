# Copyright © 2021 Mark Dumay. All rights reserved.
# Use of this source code is governed by The MIT License (MIT) that can be found in the LICENSE file.

#======================================================================================================================
# Build arguments
#======================================================================================================================
ARG CERTBOT_DNS_PLUGIN
ARG UID=1001
ARG GID=1001
ARG BUILD_USER='certbot'
ARG BUILD_FLAG=''
ARG BUILD_VERSION


#======================================================================================================================
# Main image
#======================================================================================================================
# Pull base image for specified DNS plugin
FROM certbot/dns-${CERTBOT_DNS_PLUGIN}

ARG BUILD_VERSION
ENV BUILD_VERSION "${BUILD_VERSION}"

# Copy helper scripts
COPY ./dbm/utils/harden_alpine.sh /usr/local/sbin/harden_alpine.sh
COPY ./config/certbot/certbot_issue.sh /usr/local/sbin/certbot_issue.sh
COPY ./config/certbot/docker_entrypoint.sh /usr/local/sbin/docker_entrypoint.sh

# Update grep package and assign access rights for key files and folders
# Note: shadow package is needed to support higher UIDs/GIDsARG UID
ARG UID
ARG GID
ARG BUILD_USER
ARG BUILD_FLAG
ARG CERTBOT_DNS_PLUGIN
RUN apk update -f && \
    apk --no-cache add -f busybox-suid coreutils grep shadow && \
    rm -rf /var/cache/apk/* && \
    mkdir -p /etc/certbot && \
    mkdir -p /var/lib/certbot && \
    mkdir -p /var/log/certbot && \
    chmod +x /usr/local/sbin/certbot_issue.sh && \
    chmod +x /usr/local/sbin/docker_entrypoint.sh && \
    chmod +x /usr/local/sbin/harden_alpine.sh && \
    /usr/local/sbin/harden_alpine.sh harden \
        -n "${BUILD_USER}" \
        -u "${UID}" \
        -g "${GID}" \
        --create-home \
        -d /etc/certbot \
        -d /var/lib/certbot \
        -d /var/log/certbot \
        -d "/home/${BUILD_USER}" \
        -d /tmp \
        -f /usr/local/sbin/certbot_issue.sh \
        -f /usr/local/sbin/docker_entrypoint.sh \
        -k chmod \
        "${BUILD_FLAG}" && \
    rm -f /usr/local/sbin/harden_alpine.sh

# Run the container as non-root user
ARG BUILD_USER
USER "${BUILD_USER}"

# Expose the certificates folder as volume
VOLUME [ "/etc/certbot" ]

# Run certbot script (repeats every 12 hours)
ENTRYPOINT [ "docker_entrypoint.sh" ]