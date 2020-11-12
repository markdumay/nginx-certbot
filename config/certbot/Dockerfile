# Pull base image for specified DNS plugin
ARG CERTBOT_DNS_PLUGIN
ARG UID=1001
FROM certbot/dns-${CERTBOT_DNS_PLUGIN}

# Copy helper script
COPY certbot_issue.sh /usr/local/bin/certbot_issue.sh
COPY docker_entrypoint.sh /usr/local/bin/docker_entrypoint.sh

# Update grep package and assign access rights for key files and folders
ARG UID
RUN apk update -f && \
    apk --no-cache add -f busybox-suid coreutils grep && \
    rm -rf /var/cache/apk/* && \
    addgroup -g "${UID}" -S certbot && adduser --uid "${UID}" -S certbot -G certbot && \
    mkdir -p /etc/certbot && \
    mkdir -p /var/lib/certbot && \
    mkdir -p /var/log/certbot && \
    chown certbot:certbot -R /etc/certbot && \
    chown certbot:certbot -R /var/lib/certbot && \
    chown certbot:certbot -R /var/log/certbot && \
    chown certbot:certbot /usr/local/bin/certbot_issue.sh && \
    chmod +x /usr/local/bin/certbot_issue.sh && \
    chmod +x /usr/local/bin/docker_entrypoint.sh

# Run the container as non-root user certbot
USER certbot

# Expose the certificates folder as volume
VOLUME [ "/etc/certbot" ]

# Run certbot script (repeats every 12 hours)
ENTRYPOINT [ "docker_entrypoint.sh" ]