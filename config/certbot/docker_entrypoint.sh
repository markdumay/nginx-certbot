#!/bin/sh
#=======================================================================================================================
# Title         : docker-entrypoint.sh
# Description   : Initializes and launches the certbot agent to issue Let's Encrypt wildcard certificates. The
#                 certificates are verified every 12 hours and renewed if necessary.
# Author        : Mark Dumay
# Date          : February 8th, 2021
# Version       : 0.9
# Usage         : docker-entrypoint.sh
# Repository    : https://github.com/markdumay/nginx-certbot
# Comments      :
#=======================================================================================================================

#=======================================================================================================================
# Constants
#=======================================================================================================================
readonly VALIDATION_INTERVAL="12h" # time between each validation of certificates
readonly RW_DIRS='/etc/certbot /home/certbot /tmp /var/lib/certbot /var/log/certbot'


#=======================================================================================================================
# Variables
#=======================================================================================================================
filename=$(basename "$0")


#=======================================================================================================================
# Helper Functions
#=======================================================================================================================

#=======================================================================================================================
# Displays error message on console and terminates with non-zero exit code.
#=======================================================================================================================
# Arguments:
#   $1 - Error message to display.
# Outputs:
#   Writes error message to stderr, non-zero exit code.
#=======================================================================================================================
terminate() {
    echo "${filename}: ERROR: $1"
    exit 1
}


#=======================================================================================================================
# Validates if the current shell user has R/W access to selected directories. The script terminates if a directory is
# not found, or if the permissions are incorrect.
#=======================================================================================================================
# Outputs:
#   Non-zero exit code in case of errors.
#=======================================================================================================================
validate_access() {
    log 'Validating access to key directories'
    
    # skip when R/W dirs are not specified
    if [ -n "${RW_DIRS}" ]; then
        # print directories that do not have R/W access
        dirs=$(eval "find ${RW_DIRS} -xdev -type d \
            -exec sh -c '(test -r \"\$1\" && test -w \"\$1\") || echo \"\$1\"' _ {} \; 2> /dev/null")
        result="$?"

        # capture result:
        # - non-zero result implies a directory cannot be found
        # - non-zero dirs captures directories that do not have R/W access
        [ "${result}" -ne 0 ] && terminate "Missing one or more directories: ${RW_DIRS}"
        [ -n "${dirs}" ] && terminate "Incorrect permissions: ${dirs}"
        log 'Permissions are correct'
    fi
}


#=======================================================================================================================
# Main Script
#=======================================================================================================================

#=======================================================================================================================
# Entrypoint for the script.
#=======================================================================================================================
main() {
    # validate r/w access to key directories
    validate_access

    # Init settings and then run certbot script every 12 hours
    trap : TERM INT
    certbot_issue.sh init || exit 1
    (while true; do certbot_issue.sh run; sleep "${VALIDATION_INTERVAL}"; done) & wait
}

main "$@"