#!/bin/sh
#======================================================================================================================
# Title         : certbot_issue.sh
# Description   : Runs certbot to issue or renew a wildcard certificate provided by Let's Encrypt
# Author        : Mark Dumay
# Date          : February 3rd, 2021
# Version       : 0.9
# Usage         : certbot_issue.sh
# Repository    : https://github.com/markdumay/nginx-certbot
# Comments      : Expects the following environment variables: CERTBOT_DNS_PLUGIN, CERTBOT_DOMAIN, CERTBOT_EMAIL, and
#                 CERTBOT_DEPLOYMENT. The variable CERTBOT_DNS_PROPAGATION is optional and defaults to 30 seconds. DNS
#                 credentials should be present as either Docker secret or environment variable. The invoked certbot
#                 script requires read/write access to the following folders:
#                 - /var/lib/certbot
#                 - /var/log/certbot
#                 - /etc/certbot
#======================================================================================================================

#======================================================================================================================
# Constants
#======================================================================================================================
readonly RED='\e[31m' # Red color
readonly NC='\e[m' # No color / reset
readonly BOLD='\e[1m' #Bold font
readonly LOG_FILE='/var/log/certbot/letsencrypt.log'
readonly LOG_PREFIX="$(date -u '+%F %T,%3N'):INFO:certbot_issue.sh:"
readonly SECRET_PATH="${HOME}/.secrets/certbot"
readonly DNS_PLUGINS="cloudflare cloudxns digitalocean dnsimple dnsmadeeasy gehirn google linode luadns nsone \
    ovh rfc2136 route53 sakuracloud"
readonly DEPLOYMENT_TARGET="test production"
readonly WORK_DIR='/var/lib/certbot'
readonly LOGS_DIR='/var/log/certbot'
readonly CONFIG_DIR='/etc/certbot'


#======================================================================================================================
# Global Variables
#======================================================================================================================
dns_prefix=''
dns_propagation='true'
command=''
step=0
total_steps=0


#======================================================================================================================
# Helper Functions
#======================================================================================================================

#=======================================================================================================================
# Display usage message.
#=======================================================================================================================
# Globals:
#   - backup_dir
# Outputs:
#   Writes message to stdout.
#=======================================================================================================================
usage() { 
    echo 'Script to issue a Let''s Encrypt wildcard certificate via certbot'
    echo 
    echo "Usage: $0 COMMAND [OPTIONS]" 
    echo
    echo 'Commands:'
    echo '  init                   Initialize the environment and configuration'
    echo '  run                    Issue the certificate'
    echo
}

#======================================================================================================================
# Displays error message on console and log file, terminate with non-zero error.
#======================================================================================================================
# Arguments:
#   $1 - Error message to display.
# Outputs:
#   Writes error message to stderr and optional log file, non-zero exit code.
#======================================================================================================================
terminate() {
    printf "${RED}${BOLD}%s${NC}\n" "ERROR: $1"
    if [ -n "${LOG_FILE}" ] ; then
        echo "${LOG_PREFIX}ERROR: $1" >> "${LOG_FILE}"
    fi
    exit 1
}

#======================================================================================================================
# Print current progress to the console and log file, shows progress against total number of steps.
#======================================================================================================================
# Arguments:
#   $1 - Progress message to display.
# Outputs:
#   Writes message to stdout and optional log file.
#======================================================================================================================
print_status() {
    step=$((step + 1))
    printf "${BOLD}%s${NC}\n" "Step ${step} from ${total_steps}: $1"
    if [ -n "${LOG_FILE}" ] ; then
        echo "${LOG_PREFIX}Step ${step} from ${total_steps}: $1" >> "${LOG_FILE}"
    fi
}

#======================================================================================================================
# Prints current progress to the console and optional log file.
#======================================================================================================================
# Arguments:
#   $1 - Progress message to display.
# Outputs:
#   Writes message to stdout and optional log file.
#======================================================================================================================
log() {
    echo "$1"
    if [ -n "${LOG_FILE}" ] ; then
        echo "${LOG_PREFIX}$1" >> "${LOG_FILE}"
    fi
}

#=======================================================================================================================
# Parse and validate the command-line arguments.
#=======================================================================================================================
# Globals:
#   - command
# Arguments:
#   $@ - All available command-line arguments.
# Outputs:
#   Writes warning or error to stdout if applicable, terminates with non-zero exit code on fatal error.
#=======================================================================================================================
parse_args() {
    # Process and validate command-line arguments
    while [ -n "$1" ]; do
        case "$1" in
            init ) command="$1";;
            run  ) command="$1";;
            *    ) usage; terminate "Unrecognized command ($1)"
        esac
        shift
    done

    # Validate arguments
    fatal_error=''
    # Requirement 1 - a single value command is provided
    if [ -z "${command}" ]; then fatal_error="Expected command"
    fi

    # Inform user and terminate on fatal error
    [ -n "${fatal_error}" ] && usage && terminate "${fatal_error}"
}

#======================================================================================================================
# Validates if a specific (case-sensitive) string element exists in an array. This is a helper function, as POSIX-
# compliant shell scripts do not support arrays natively. The pseudo array expects spaces as separator.
#======================================================================================================================
# Arguments:
#   $1 - Pseudo array with all elements, separated by spaces
#   $2 - String elements to test for.
# Returns:
#   0 if element is found, non-zero otherwise.
#======================================================================================================================
element_exists() {
    if echo "$1" | grep -qw "$2" ; then return 0; else return 1; fi
}

#======================================================================================================================
# Validates if a specified DNS plugin is recognized. Supported plugins are: cloudflare, cloudxns, digitalocean,
# dnsimple, dnsmadeeasy, gehirn, google, linode, luadns, nsone, ovh, rfc2136, route53n and sakuracloud. 
#======================================================================================================================
# Arguments:
#   $1 - DNS plugin to be verified.
# Returns:
#   0 if DNS is supported, non-zero otherwise.
#======================================================================================================================
is_valid_dns_plugin() {
    element_exists "${DNS_PLUGINS}" "$1"
}

#======================================================================================================================
# Validates if a specified deployment target is recognized.
#======================================================================================================================
# Arguments:
#   $1 - Deployment target to be verified.
# Returns:
#   0 if deployment target is supported, non-zero otherwise.
#======================================================================================================================
is_valid_deployment_target() {
    element_exists "${DEPLOYMENT_TARGET}" "$1"
}

#======================================================================================================================
# Validates if a specified fully qualified domain name or subdomain adheres to the expected format.
#======================================================================================================================
# Arguments:
#   $1 - Domain to be verified. International names need to be converted to punycode ('xn--*') first.
# Returns:
#   Returns 0 if domain is supported, non-zero otherwise.
#======================================================================================================================
is_valid_domain() {
    domain_regex='^((?=[a-z0-9-]{1,63}\.)(xn--)?[a-z0-9]+(-[a-z0-9]+)*\.)+[a-z]{2,63}$'
    match=$(echo "$1" | grep -Pi "${domain_regex}")
    ([ -z "${match}" ] && return 1) || return 0
}

#======================================================================================================================
# Validates if a specified email address adheres to the expected format. Calls is_valid_domain() to validate the domain
# name. The test is based on this gist: https://gist.github.com/guessi/82a73ee7eb2b1216eb9db17bb8d65dd1.
#======================================================================================================================
# Arguments:
#   $1 - Email address to be verified. International names need to be converted to punycode ('xn--*') first.
# Returns:
#   Returns 0 if email address is supported, non-zero otherwise.
#======================================================================================================================
is_valid_email() {
    local_email_regex='^(([A-Za-z0-9]+((\.|\-|\_|\+)?[A-Za-z0-9]?)*[A-Za-z0-9]+)|[A-Za-z0-9]+)$'
    local_email=$(echo "$1" | tr '@' '\n' | sed -n 1p)
    domain_name=$(echo "$1" | tr '@' '\n' | sed -n 2p)
    match=$(echo "${local_email}" | grep -Pi "${local_email_regex}")
    ([ -z "${match}" ] && return 1) || is_valid_domain "${domain_name}"
}

#======================================================================================================================
# Validates if a specified argument is a positive number.
#======================================================================================================================
# Arguments:
#   $1 - Number to be verified.
# Returns:
#   Returns 0 if the argument is a positive number, non-zero otherwise.
#======================================================================================================================
is_valid_number() {
    case "$1" in
        (*[!0-9]*|'') return 1;;
        (*)           return 0;;
    esac
}


#======================================================================================================================
# Workflow Functions
#======================================================================================================================

#======================================================================================================================
# Initializes and validates environment variables. If present, Docker secrets are exported as environment variable
# too. Expects the following variables to be present and valid:
#   - CERTBOT_DNS_PLUGIN: DNS plugin to be used by certbot via DNS-01 check.
#   - CERTBOT_DOMAIN: Domain to issue a wildcard certificate for (wildcard prefix is added automatically).
#   - CERTBOT_EMAIL: Email address for important account notifications.
#   - CERTBOT_DEPLOYMENT: Indicates to deploy for 'test' or 'production'.
# The following variables are optional:
#   - CERTBOT_DNS_PROPAGATION: The number of seconds to wait for DNS to propagate before asking the ACME server 
#     to verify the DNS record. The default value varies per DNS plugin, but typically ranges between 10 and 1200
#     seconds.
#======================================================================================================================
# Globals:
#   - CERTBOT_DNS_PLUGIN
#   - CERTBOT_DOMAIN
#   - CERTBOT_EMAIL
#   - CERTBOT_DEPLOYMENT
#   - CERTBOT_DNS_PROPAGATION
#   - dns_prefix
#   - dns_propagation
# Outputs:
#   Terminates with non-zero exit code if variables are missing or invalid
#======================================================================================================================
init_env() {
    print_status "Initializing configuration"

    # export any Docker secret as environment variable
    secrets=$(grep -vH --null '^#' /run/secrets/* 2> /dev/null | tr '\0' '=' | sed 's/^\/run\/secrets\///g')
    if [ -n "${secrets}" ] ; then export "${secrets?}"; fi

    # adjust to lower case for CERTBOT_DNS_PLUGIN and CERTBOT_DEPLOYMENT
    CERTBOT_DNS_PLUGIN=$(echo "${CERTBOT_DNS_PLUGIN}" | tr '[:upper:]' '[:lower:]')
    CERTBOT_DEPLOYMENT=$(echo "${CERTBOT_DEPLOYMENT}" | tr '[:upper:]' '[:lower:]')

    # validate mandatory parameters
    is_valid_dns_plugin "${CERTBOT_DNS_PLUGIN}"
    [ $? = 1 ] && terminate "Invalid or missing DNS plugin"
    is_valid_domain "${CERTBOT_DOMAIN}"
    [ $? = 1 ] && terminate "Invalid or missing domain name"
    is_valid_domain "${CERTBOT_EMAIL}"
    [ $? = 1 ] && terminate "Invalid or missing email address"
    is_valid_deployment_target "${CERTBOT_DEPLOYMENT}"
    [ $? = 1 ] && CERTBOT_DEPLOYMENT='test' && log "WARN: Deployment target not recognized, setting to 'test'"

    # validate optional parameters
    is_valid_number "${CERTBOT_DNS_PROPAGATION}"
    [ $? = 1 ] && dns_propagation='false' && log "INFO: Setting DNS propagation to default"

    # define prefix for DNS plugin credentials
    if [ "${CERTBOT_DNS_PLUGIN}" = 'google' ] ; then
        # Google is not supported (use a json file instead)
        log "WARN: Google credentials not generated, manually provide a separate .json instead"
        dns_prefix=''
    elif [ "${CERTBOT_DNS_PLUGIN}" = 'route53' ] ; then
        # change prefix for route53 to aws (Amazon Web Services)
        dns_prefix='aws_'
    else
        dns_prefix="dns_${CERTBOT_DNS_PLUGIN}_"
    fi

    # validate DNS plugin credentials are set (unless the plugin is Google)
    if [ -n "${dns_prefix}" ] ; then
        if ! env | grep -iq "^${dns_prefix}*"; then
            terminate "Missing DNS plugin credentials"
        fi
    fi
}

#======================================================================================================================
# Generates a certbot configuration file using the provided DNS plugin credentials. Any existing configuration file 
# is overwritten. The configuration for Google is not generated, use a proper .json file instead.
#======================================================================================================================
# Globals:
#   - CERTBOT_DNS_PLUGIN
#   - dns_prefix
# Outputs:
#   A configuration file for specified the DNS plugin, placed in the home directory of root.
#======================================================================================================================
generate_certbot_config() {
    print_status "Updating certbot configuration"

    config_file="${SECRET_PATH}/${CERTBOT_DNS_PLUGIN}.ini"
    log "Generating certbot configuration file ('${config_file}')"

    # write credentials to specified configuration file (file is overwritten)
    mkdir -p "${SECRET_PATH}"
    env | grep -i "^${dns_prefix}*" | awk -F'=' '{print tolower($1)"="$2}' > "${config_file}"
    chmod 600 "${config_file}"
}

#======================================================================================================================
# Runs certbot to issue or renew a wildcard certificate. It uses 'certonly' as the 'renew' command does not work well 
# with wildcard certificates. Existing certificates are renewed if they expire in less than 30 days.
#======================================================================================================================
# Globals:
#   - CERTBOT_DNS_PLUGIN
#   - CERTBOT_DOMAIN
#   - CERTBOT_EMAIL
#   - CERTBOT_DEPLOYMENT
#   - CERTBOT_DNS_PROPAGATION
#   - dns_prefix
#   - dns_propagation
# Outputs:
#   Symlinks to renewed or existing certificates in the folder '/etc/letsencrypt/live'. Files include:
#     - privkey.pem:   Private key for the certificate.
#     - fullchain.pem: All certificates, including server certificate (aka leaf certificate or end-entity certificate). 
#                      The server certificate is the first one in this file, followed by any intermediates. This is 
#                      what Apache >= 2.4.8 needs for SSLCertificateFile, and what Nginx needs for ssl_certificate.
#     - cert.pem:      Contains the server certificate by itself
#     - chain.pem:     Contains the additional intermediate certificate or certificates that web browsers will need in 
#                      order to validate the server certificate. If you’re using OCSP stapling with Nginx >= 1.3.7, 
#                      chain.pem should be provided as the ssl_trusted_certificate to validate OCSP responses.
#======================================================================================================================
run_certbot() {
    print_status "Issuing certificate for '${CERTBOT_DOMAIN}'"
    log "Running in ${CERTBOT_DEPLOYMENT} mode"

    # TODO: backup/restore arguments
    # original_cmd=$*

    # TODO: add date/timestamp
    log "Executing certbot"
    set -- certbot certonly
    set -- "$@" --work-dir "${WORK_DIR}"
    set -- "$@" --logs-dir "${LOGS_DIR}"
    set -- "$@" --config-dir "${CONFIG_DIR}"
    set -- "$@" "--dns-${CERTBOT_DNS_PLUGIN}"
    set -- "$@" "--dns-${CERTBOT_DNS_PLUGIN}-credentials" "${SECRET_PATH}/${CERTBOT_DNS_PLUGIN}.ini"
    if [ "${dns_propagation}" = 'true' ] ; then
        set -- "$@" "--dns-${CERTBOT_DNS_PLUGIN}-propagation-seconds" "${CERTBOT_DNS_PROPAGATION}"
    fi
    set -- "$@" -d "${CERTBOT_DOMAIN}"
    set -- "$@" -d "*.${CERTBOT_DOMAIN}"
    set -- "$@" -m "${CERTBOT_EMAIL}"
    set -- "$@" -n
    set -- "$@" --agree-tos
    if [ "${CERTBOT_DEPLOYMENT}" != 'production' ] ; then
        set -- "$@" --dry-run 
        set -- "$@" --test-cert
    fi

    "$@" || terminate "Certbot failed, please check correct installation and verify parameters"
}

#======================================================================================================================
# Entrypoint for the script. It initializes the environment variables, generates the DNS plugin configuration, and
# runs the certbot to issue/renew the certificate.
#======================================================================================================================
main() {
    # Parse arguments
    parse_args "$@"

    # Execute workflows
    case "${command}" in
        init )
            total_steps=2
            init_env
            generate_certbot_config
            ;;
        run  )
            total_steps=1
            run_certbot
            ;;
        *)       
            terminate 'Invalid command'
    esac

    echo 'Done.'
}

main "$@"