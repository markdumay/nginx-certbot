#!/bin/sh
#======================================================================================================================
# Title         : docker-entrypoint.sh
# Description   : Launches Nginx using server configuration templates. The execution starts once certificates are 
#                 available. Nginx is reloaded automatically on updated templates or certificates.
# Author        : Mark Dumay
# Date          : November 11th, 2020
# Version       : 0.5
# Usage         : docker-entrypoint.sh
# Repository    : https://github.com/markdumay/nginx-certbot
# Comments      : 
#======================================================================================================================

#======================================================================================================================
# Constants
#======================================================================================================================
readonly CERT_PATH="/etc/certbot/live/${CERTBOT_DOMAIN}"
readonly ENTRYPOINT_PATH='/docker-entrypoint.d'
readonly NGINX_CONF_DIR='/etc/nginx/conf.d'
readonly NGINX_SNIPPETS_DIR='/etc/nginx/snippets'
readonly NGINX_TEMPLATES_DIR='/etc/nginx/templates'
readonly NGINX_TEMPLATE_CMD='/docker-entrypoint.d/20-envsubst-on-templates.sh'
# readonly POLLING_INTERVAL=60  # seconds
readonly POLLING_INTERVAL=5  # TODO: temp

#======================================================================================================================
# Launches any initial entrypoints scripts available in '/docker-entrypoint.d/' (source code is copied from the Nginx 
# Docker repository). One of the default scripts ('20-envsubst-on-templates.sh') generates server configurations based
# on templates available in the '/etc/nginx/templates' folder. Any other defined entrypoints scripts are executed too.
#======================================================================================================================
# Outputs:
#   Generated server configurations in '/etc/nginx/conf.d', plus output from additionally defined entrypoint scripts.
#======================================================================================================================
launch_entrypoint_scripts() {
    if find "${ENTRYPOINT_PATH}/" -mindepth 1 -maxdepth 1 -type f -print -quit 2>/dev/null | read -r v; then
        echo >&3 "$0: ${ENTRYPOINT_PATH}/ is not empty, will attempt to perform configuration"

        echo >&3 "$0: Looking for shell scripts in ${ENTRYPOINT_PATH}/"
        find "${ENTRYPOINT_PATH}/" -follow -type f -print | sort -n | while read -r f; do
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
        echo >&3 "$0: No files found in ${ENTRYPOINT_PATH}/, skipping configuration"
    fi
}

#======================================================================================================================
# Watches the folders '/etc/nginx/templates', '/etc/nginx/templates/snippets', and 
# '/etc/certbot/live/${CERTBOT_DOMAIN}' for any changes. Observed files should have a '.template' or '.conf' suffix.
# In case a template has been changed, has been added, or has been removed, existing server configurations are removed 
# entirely and recreated. Nginx is reloaded once the templates have been processed, or when a modified certificate is 
# detected. The polling interval is set to one minute.
#======================================================================================================================
# Outputs:
#   Updated server configurations in '/etc/nginx/conf.d' and snippets in '/etc/nginx/snippets'; reloaded Nginx process.
#======================================================================================================================
reload_nginx_on_change() {
    prev_incoming_checksum=$(find -L "${NGINX_TEMPLATES_DIR}" -type f \( -iname \*.template -o -iname \*.conf \) \
        -exec md5sum {} \; -maxdepth 2 2>/dev/null | sort) # covers templates and snippets
    prev_cert_checksum=$(find -L "${CERT_PATH}"/*.pem -type f -exec md5sum {} \; -maxdepth 1 2>/dev/null | sort)
    while true
    do 
        sleep "${POLLING_INTERVAL}"

        # scan for any new templates or certificates
        current_config=$(cd "${NGINX_CONF_DIR}" && find -L ./*.conf -type f -maxdepth 1 2>/dev/null | sort)
        current_snippets=$(cd "${NGINX_SNIPPETS_DIR}" && find -L ./*.conf -type f -maxdepth 1 2>/dev/null | sort)
        if [ -d "${NGINX_TEMPLATES_DIR}"/snippets ]; then
            snippet_config=$(cd "${NGINX_TEMPLATES_DIR}"/snippets && find -L ./*.conf -type f -maxdepth 1 2>/dev/null | \
                sort)
        else
            snippet_config=''
        fi
        template_config=$(cd "${NGINX_TEMPLATES_DIR}" && find -L ./*.template -type f -maxdepth 1 2>/dev/null | \
            sed -e "s/.template//" | sort)
        new_incoming_checksum=$(find -L "${NGINX_TEMPLATES_DIR}" -type f \( -iname \*.template -o -iname \*.conf \) \
            -exec md5sum {} \; -maxdepth 2 2>/dev/null | sort)
        new_cert_checksum=$(find -L "${CERT_PATH}"/*.pem -type f -exec md5sum {} \; -maxdepth 1 2>/dev/null | sort)

        # generate new configuration on any new/changed templates and reload nginx
        if  [ "${current_config}" != "${template_config}" ] || \
            [ "${current_snippets}" != "${snippet_config}" ] || \
            [ "${new_incoming_checksum}" != "${prev_incoming_checksum}" ]; then
            
            echo >&3 "$0: Changes detected, reconfiguring sites"
            # remove existing configurations
            rm -rf "${NGINX_CONF_DIR}"/*.conf "${NGINX_SNIPPETS_DIR}"/*.conf || true
            # copy incoming snippets
            \cp -r "${NGINX_TEMPLATES_DIR}"/snippets/*.conf "${NGINX_SNIPPETS_DIR}"/ 2>/dev/null || true
            # regenerate configurations based on templates and update checksum
            "${NGINX_TEMPLATE_CMD}"
            prev_incoming_checksum="${new_incoming_checksum}"
            # reload nginx
            "$1" -t && "$1" -s reload
        # reload nginx to use renewed cerfificates
        elif [ "${new_cert_checksum}" != "${prev_cert_checksum}" ]; then
            prev_cert_checksum="${new_cert_checksum}"
            "$1" -t && "$1" -s reload
        fi
    done    
}

#======================================================================================================================
# Waits for certificates in the folder '/etc/certbot/live/${CERTBOT_DOMAIN}' to become available. This prevents 
# starting Nginx prematurely. The polling interval is set to one minute.
#======================================================================================================================
# Outputs:
#   Paused script execution until certificates are available.
#======================================================================================================================
wait_for_certificates() {
    while [ ! -f "${CERT_PATH}/fullchain.pem" ] || [ ! -f "${CERT_PATH}/privkey.pem" ]
    do
        echo >&3 "$0: Waiting for certificates ('${CERT_PATH}')"
        sleep "${POLLING_INTERVAL}"
    done
}

#======================================================================================================================
# Entrypoint for the script.
#======================================================================================================================
main() {
    if [ "$1" = "nginx" ] || [ "$1" = "nginx-debug" ]; then
        # configure logging redirection
        set -e
        if [ -z "${NGINX_ENTRYPOINT_QUIET_LOGS:-}" ]; then
            exec 3>&1
        else
            exec 3>/dev/null
        fi

        # setup initial nginx configuration, including certificates
        rm -f "${NGINX_CONF_DIR}"/*.conf || true # remove any existing configurations at launch
        launch_entrypoint_scripts "$@"
        wait_for_certificates "$@"

        # start nginx in foreground and scan for any configuration changes
        "$1" -g 'daemon off;' & echo >&3 "$0: Started nginx" & reload_nginx_on_change "$@"
    fi
}

main "$@"