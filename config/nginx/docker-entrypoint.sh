#!/bin/sh
# vim:sw=4:ts=4:et

# configure logging redirection
set -e

if [ -z "${NGINX_ENTRYPOINT_QUIET_LOGS:-}" ]; then
    exec 3>&1
else
    exec 3>/dev/null
fi

# launch any initial entrypoint scripts (copied from nginx repository)
if [ "$1" = "nginx" ] || [ "$1" = "nginx-debug" ]; then
    if /usr/bin/find "/docker-entrypoint.d/" -mindepth 1 -maxdepth 1 -type f -print -quit 2>/dev/null | read -r v; then
        echo >&3 "$0: /docker-entrypoint.d/ is not empty, will attempt to perform configuration"

        echo >&3 "$0: Looking for shell scripts in /docker-entrypoint.d/"
        find "/docker-entrypoint.d/" -follow -type f -print | sort -n | while read -r f; do
            case "$f" in
                *.sh)
                    if [ -x "$f" ]; then
                        echo >&3 "$0: Launching $f"
                        "$f"
                    else
                        # warn on shell scripts without exec bit
                        echo >&3 "$0: Ignoring $f, not executable"
                    fi
                    ;;
                *) 
                    echo >&3 "$0: Ignoring $f"
                    ;;
            esac
        done

        echo >&3 "$0: Configuration complete; ready for start up"
    else
        echo >&3 "$0: No files found in /docker-entrypoint.d/, skipping configuration"
    fi
fi

# wait for certificates to become available
readonly CERT_PATH="/etc/letsencrypt/live/${CERTBOT_DOMAIN}"
while [ ! -f "${CERT_PATH}/fullchain.pem" ] || [ ! -f "${CERT_PATH}/privkey.pem" ]
# while ! ls -A "/etc/letsencrypt/live/${CERTBOT_DOMAIN}" > /dev/null 2>&1 ;
do
    echo >&3 "$0: Waiting for certificates ('${CERT_PATH}')"
    sleep 30
done

# start nginx in foreground and reload every 6 hours to renew any cerfificates
"$1" -g 'daemon off;'
while true
do 
    sleep 6h
    "$1" -s reload
done