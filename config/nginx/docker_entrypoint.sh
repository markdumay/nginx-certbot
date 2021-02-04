#!/bin/sh
#=======================================================================================================================
# Title         : docker-entrypoint.sh
# Description   : Launches Nginx using server configuration templates. The execution starts once certificates are 
#                 available. Nginx is reloaded automatically on updated templates or certificates.
# Author        : Mark Dumay
# Date          : February 2nd, 2021
# Version       : 0.9
# Usage         : docker-entrypoint.sh
# Repository    : https://github.com/markdumay/nginx-certbot
# Comments      : 
#=======================================================================================================================

#=======================================================================================================================
# Constants
#=======================================================================================================================
readonly BOOT_TIME=5 # time in seconds to wait for the nginx master and worker processes to have started
readonly CERT_PATH="/etc/certbot/live/${CERTBOT_DOMAIN}"
readonly ENTRYPOINT_PATH='/docker-entrypoint.d'
readonly NGINX_CONF_DIR='/etc/nginx/conf.d'
readonly NGINX_SNIPPETS_DIR='/etc/nginx/snippets'
readonly NGINX_TEMPLATES_DIR='/etc/nginx/templates'
readonly NGINX_TEMPLATE_CMD='/docker-entrypoint.d/20-envsubst-on-templates.sh'


#=======================================================================================================================
# Variables
#=======================================================================================================================
polling_interval="${NGINX_POLLING_INTERVAL:-60}" # seconds
filename=$(basename "$0")


#=======================================================================================================================
# Displays a log message on console.
#=======================================================================================================================
# Arguments:
#   $1 - Message to display.
# Outputs:
#   Writes log message to stdout.
#=======================================================================================================================
log() {
    echo >&3 "${filename}: $1"
}

#=======================================================================================================================
# Displays error message on console and terminates with non-zero error.
#=======================================================================================================================
# Arguments:
#   $1 - Error message to display.
# Outputs:
#   Writes error message to stderr, non-zero exit code.
#=======================================================================================================================
terminate() {
    echo >&3 "${filename}: ERROR: $1"
    exit 1
}

#=======================================================================================================================
# Launches any initial entrypoints scripts available in '/docker-entrypoint.d/' (source code is copied from the Nginx 
# Docker repository). One of the default scripts ('20-envsubst-on-templates.sh') generates server configurations based
# on templates available in the '/etc/nginx/templates' folder. Any other defined entrypoints scripts are executed too.
#=======================================================================================================================
# Outputs:
#   Generated server configurations in '/etc/nginx/conf.d', plus output from additionally defined entrypoint scripts.
#=======================================================================================================================
launch_entrypoint_scripts() {
    if find "${ENTRYPOINT_PATH}/" -mindepth 1 -maxdepth 1 -type f -print -quit 2>/dev/null | read -r; then
        log "${ENTRYPOINT_PATH}/ is not empty, will attempt to perform configuration"

        log "Looking for shell scripts in ${ENTRYPOINT_PATH}/"
        find "${ENTRYPOINT_PATH}/" -follow -type f -print | sort -n | while read -r f; do
            case "${f}" in
                *.sh)
                    if [ -x "${f}" ]; then
                        log "Launching $f"
                        "${f}"
                    else
                        # warn on shell scripts without exec bit
                        log "Ignoring ${f}, not executable"
                    fi
                    ;;
                *) 
                    log "Ignoring ${f}"
                    ;;
            esac
        done

        log "Configuration complete; ready for start up"
    else
        log "No files found in '${ENTRYPOINT_PATH}/', skipping configuration"
    fi
}

#=======================================================================================================================
# Watches the folders '/etc/nginx/templates', '/etc/nginx/templates/snippets', and 
# '/etc/certbot/live/${CERTBOT_DOMAIN}' for any changes. Observed files should have a '.template' or '.conf' suffix.
# In case a template has been changed, has been added, or has been removed, existing server configurations are removed 
# entirely and recreated. Nginx is reloaded once the templates have been processed, or when a modified certificate is 
# detected. The polling interval is set to one minute by default.
#=======================================================================================================================
# Globals:
#  - boot_failure
#  - polling_interval
# Outputs:
#   Updated server configurations in '/etc/nginx/conf.d' and snippets in '/etc/nginx/snippets'; reloaded Nginx process.
#=======================================================================================================================
reload_nginx_on_change() {
    prev_incoming_checksum=$(find -L "${NGINX_TEMPLATES_DIR}" -type f \( -iname \*.template -o -iname \*.conf \) \
        -exec md5sum {} \; -maxdepth 2 2>/dev/null | sort) # covers templates and snippets
    prev_cert_checksum=$(find -L "${CERT_PATH}"/*.pem -type f -exec md5sum {} \; -maxdepth 1 2>/dev/null | sort)
    while true
    do 
        sleep "${polling_interval}"

        # scan for any new templates or certificates
        current_config=$(cd "${NGINX_CONF_DIR}" && find -L ./*.conf -type f -maxdepth 1 2>/dev/null | sort)
        current_snippets=$(cd "${NGINX_SNIPPETS_DIR}" && find -L ./*.conf -type f -maxdepth 1 2>/dev/null | sort)
        if [ -d "${NGINX_TEMPLATES_DIR}"/snippets ]; then
            snippet_config=$(cd "${NGINX_TEMPLATES_DIR}"/snippets && \
                find -L ./*.conf -type f -maxdepth 1 2>/dev/null | sort)
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
            
            log "Changes detected, reconfiguring sites"
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

#=======================================================================================================================
# Verifies nginx has started successfully. It validates the presence of at least one nginx worker process after a grace 
# period for the boot process.
#=======================================================================================================================
# Outputs:
#   Prints nginx status to stdout, terminates with non-zero exit code on eror.
#=======================================================================================================================
start_and_verify_nginx() {
    # confirm command can be found
    if ! command -v "$1" > /dev/null; then terminate "Command '$1' not found"; fi
    
    # start nginx and capture PID of the master process
    log "Starting nginx..."
    "$1" -g 'daemon off;' &
    nginx_pid="$!"

    # check at least one worker process is available after grace period and return the master PID accordingly
    sleep "${BOOT_TIME}"
    if ! pgrep -f 'nginx: worker process' > /dev/null 2>&1; then
        nginx_pid=0
        terminate "Error starting nginx"
    fi
}

#=======================================================================================================================
# Waits for certificates in the folder '/etc/certbot/live/${CERTBOT_DOMAIN}' to become available. This prevents 
# starting Nginx prematurely. The polling interval is set to one minute by default.
#=======================================================================================================================
# Globals:
#  - polling_interval
# Outputs:
#   Paused script execution until certificates are available.
#=======================================================================================================================
wait_for_certificates() {
    while [ ! -f "${CERT_PATH}/fullchain.pem" ] || [ ! -f "${CERT_PATH}/privkey.pem" ]
    do
        log "Waiting for certificates ('${CERT_PATH}')"
        sleep "${polling_interval}"
    done
}

#=======================================================================================================================
# Entrypoint for the script.
#=======================================================================================================================
main() {
    # configure logging redirection
    set -e
    if [ -z "${NGINX_ENTRYPOINT_QUIET_LOGS:-}" ]; then
        exec 3>&1
    else
        exec 3>/dev/null
    fi

    if [ "$1" = "nginx" ] || [ "$1" = "nginx-debug" ]; then
        # setup initial nginx configuration, including certificates
        rm -f "${NGINX_CONF_DIR}"/*.conf || true # remove any existing configurations at launch
        launch_entrypoint_scripts "$@"
        wait_for_certificates "$@"

        # start nginx and scan for any configuration changes
        start_and_verify_nginx "$1"
        if [ "${nginx_pid}" -gt 0 ]; then
            log "nginx started successfully"
            wait "${nginx_pid}" & reload_nginx_on_change "$@"
        else
            log "Unknown error"
            exit 1
        fi
    else
        terminate "Invalid command '$1'"
    fi
}

main "$@"