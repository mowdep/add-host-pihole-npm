#!/usr/bin/env bash
# ======================================================
# Automated DNS and Proxy Configuration Script
# ======================================================
# Creates CNAME records in Pi-hole and configures
# proxy hosts in Nginx Proxy Manager
# Author: mowdep
# Date: 2025-04-25
# ======================================================

set -eo pipefail

# Configuration
PIHOLE_URL="https://CHANGEME"
NPM_URL="https://CHANGEME"
DOMAIN_SUFFIX="CHANGEME"
CERT_ID=2 #Should be a number. Order as in the Webui
PROXY_TARGET="proxy.${DOMAIN_SUFFIX}"
NPM_EMAIL="npm_email@email.co"
NPM_PASSWORD="npm_password"
DEBUG=${DEBUG:-false}

# ANSI color codes
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly BLUE='\033[0;34m'
readonly YELLOW='\033[0;33m'
readonly PURPLE='\033[0;35m'
readonly NC='\033[0m' # No Color

# Function to display usage information
usage() {
  echo -e "${BLUE}ℹ️  Usage:${NC} $0 [OPTIONS]"
  echo ""
  echo "Required arguments (at least one operation must be selected):"
  echo "  --dest SUBDOMAIN       Subdomain to create (e.g., 'toto' creates toto.${DOMAIN_SUFFIX})"
  echo "  --source IP:PORT       Backend service IP and port (e.g., '192.168.1.50:3456')"
  echo ""
  echo "Operation selection:"
  echo "  --cname-only           Only add CNAME record to Pi-hole (requires --dest)"
  echo "  --proxy-only           Only add proxy host to Nginx Proxy Manager (requires --dest and --source)"
  echo "  (If neither is specified, both operations will be performed)"
  echo ""
  echo "Optional arguments:"
  echo "  --force                Overwrite existing entries if they exist"
  echo "  --debug                Enable verbose debug output"
  echo "  --help                 Display this help message"
  echo ""
  echo "Examples:"
  echo "  $0 --dest toto --source 192.168.1.50:3456"
  echo "  $0 --dest toto --cname-only"
  echo "  $0 --dest toto --source 192.168.1.50:3456 --proxy-only --debug"
  exit 1
}

# Logging functions
log_info() {
  echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
  echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
  echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
  echo -e "${RED}❌ $1${NC}"
}

log_debug() {
  if [[ "${DEBUG}" == "true" ]]; then
    echo -e "${PURPLE}🔍 $1${NC}"
  fi
}

# Function to add CNAME record to Pi-hole
add_cname_record() {
  log_info "Adding CNAME record to Pi-hole: ${FQDN} → ${PROXY_TARGET}"

  # Format the URL properly - Pi-hole API expects URL-encoded parameters
  local api_endpoint="${PIHOLE_URL}/api/config/dns/cnameRecords/${FQDN}%2C${PROXY_TARGET}"
  log_debug "Pi-hole API endpoint: ${api_endpoint}"

  # Make the API call to Pi-hole
  local http_response
  local curl_cmd="curl -s -w '%{http_code}' -X PUT '${api_endpoint}'"
  
  log_debug "Executing: ${curl_cmd}"
  http_response=$(eval "${curl_cmd}")
  
  local status_code="${http_response: -3}"
  local response="${http_response:0:${#http_response}-3}"
  
  log_debug "Pi-hole status code: ${status_code}"
  log_debug "Pi-hole response: ${response}"
  
  if [[ "${status_code}" =~ ^2[0-9][0-9]$ ]]; then
    log_success "CNAME record added successfully"
    return 0
  else
    log_error "Failed to add CNAME record to Pi-hole (Status: ${status_code})"
    log_error "Response: ${response}"
    return 1
  fi
}

# Function to get NPM token
get_npm_token() {
  log_debug "Authenticating with Nginx Proxy Manager..."
  
  local npm_creds="{\"identity\":\"${NPM_EMAIL}\",\"secret\":\"${NPM_PASSWORD}\"}"
  local curl_cmd="curl -s -X POST -H 'Content-Type: application/json' -d '${npm_creds}' '${NPM_URL}/api/tokens'"
  
  log_debug "Auth request: ${curl_cmd}"
  local response
  response=$(eval "${curl_cmd}")
  
  log_debug "Auth response: ${response}"
  
  local token
  token=$(echo "${response}" | jq -r '.token // empty')
  
  if [[ -z "${token}" ]]; then
    log_error "Failed to authenticate with Nginx Proxy Manager"
    log_error "Response: ${response}"
    return 1
  fi
  
  echo "${token}"
  return 0
}

# Check if a proxy host exists
check_proxy_exists() {
  local domain="$1"
  local token="$2"
  
  log_debug "Checking if proxy host exists for ${domain}..."
  
  local curl_cmd="curl -s -H 'Authorization: Bearer ${token}' '${NPM_URL}/api/nginx/proxy-hosts'"
  log_debug "List proxy hosts: ${curl_cmd}"
  
  local response
  response=$(eval "${curl_cmd}")
  
  log_debug "Proxy list response length: $(echo "${response}" | jq -r 'length')"
  
  # Check each proxy host for matching domain
  local proxy_id
  proxy_id=$(echo "${response}" | jq -r --arg domain "${domain}" '.[] | select(.domain_names | contains([$domain])) | .id // empty')
  
  if [[ -n "${proxy_id}" ]]; then
    log_debug "Found proxy host with ID: ${proxy_id}"
    echo "${proxy_id}"
    return 0
  fi
  
  log_debug "No matching proxy host found"
  return 1
}

# Function to add proxy host to Nginx Proxy Manager
add_proxy_host() {
  log_info "Configuring Nginx Proxy Manager for ${FQDN}"

  # Get NPM token
  local npm_token
  npm_token=$(get_npm_token) || return 1

  # Check if the proxy host already exists
  local proxy_id
  if proxy_id=$(check_proxy_exists "${FQDN}" "${npm_token}"); then
    if [[ "${FORCE}" != "true" ]]; then
      log_error "Proxy host already exists for ${FQDN} (ID: ${proxy_id}). Use --force to overwrite."
      return 1
    else
      log_warning "Deleting existing proxy host (ID: ${proxy_id})..."
      
      local curl_cmd="curl -s -X DELETE -H 'Authorization: Bearer ${npm_token}' '${NPM_URL}/api/nginx/proxy-hosts/${proxy_id}'"
      log_debug "Delete command: ${curl_cmd}"
      
      local delete_response
      delete_response=$(eval "${curl_cmd}")
      
      log_debug "Delete response: ${delete_response}"
      log_warning "Removed existing proxy host (ID: ${proxy_id})"
    fi
  fi

  # Only send required fields that NPM API accepts
  # This is a minimal valid payload based on NPM API requirements
  local proxy_data='{
    "domain_names": ["'"${FQDN}"'"],
    "forward_host": "'"${IP}"'",
    "forward_port": '"${PORT}"',
    "forward_scheme": "http",
    "certificate_id": '"${CERT_ID}"',
    "ssl_forced": true,
    "block_exploits": true,
    "caching_enabled": false,
    "allow_websocket_upgrade": true,
    "http2_support": true,
    "access_list_id": 0
  }'
  
  log_debug "NPM payload:"
  log_debug "$(echo "${proxy_data}" | jq '.')"
  
  # Add the proxy host
  log_debug "Creating new proxy host..."
  local curl_cmd="curl -s -w '%{http_code}' -X POST -H 'Authorization: Bearer ${npm_token}' -H 'Content-Type: application/json' -d '${proxy_data}' '${NPM_URL}/api/nginx/proxy-hosts'"
  log_debug "Create command: ${curl_cmd}"
  
  local http_response
  http_response=$(eval "${curl_cmd}")
  
  local status_code="${http_response: -3}"
  local response="${http_response:0:${#http_response}-3}"
  
  log_debug "Create status code: ${status_code}"
  log_debug "Create response: ${response}"
  
  if [[ "${status_code}" =~ ^2[0-9][0-9]$ ]]; then
    local new_id
    new_id=$(echo "${response}" | jq -r '.id // empty')
    if [[ -n "${new_id}" ]]; then
      log_success "Proxy host configured successfully with HTTPS (ID: ${new_id})"
      return 0
    fi
  fi

  log_error "Failed to create proxy host in Nginx Proxy Manager (Status: ${status_code})"
  log_error "Response: ${response}"
  
  # Attempt to provide more helpful information
  if [[ "${response}" == *"additional properties"* ]]; then
    log_warning "The API rejected some fields in the request payload. Try with minimal fields only."
    if [[ "${DEBUG}" != "true" ]]; then
      log_warning "Run with --debug for more information."
    fi
  fi
  
  return 1
}

# Parse command line arguments
FORCE=false
CNAME_ONLY=false
PROXY_ONLY=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dest)
      SUBDOMAIN="$2"
      shift 2
      ;;
    --source)
      SOURCE="$2"
      shift 2
      ;;
    --force)
      FORCE=true
      shift
      ;;
    --cname-only)
      CNAME_ONLY=true
      shift
      ;;
    --proxy-only)
      PROXY_ONLY=true
      shift
      ;;
    --debug)
      DEBUG=true
      shift
      ;;
    --help)
      usage
      ;;
    *)
      log_error "Unknown option: $1"
      usage
      ;;
  esac
done

# Show debug status
[[ "${DEBUG}" == "true" ]] && log_debug "Debug mode enabled! 🐛"

# Validate required arguments
if [[ -z "${SUBDOMAIN}" ]]; then
  log_error "Error: Subdomain (--dest) is required"
  usage
fi

# If both flags are on, it's the same as none being on
if [[ "${CNAME_ONLY}" == true && "${PROXY_ONLY}" == true ]]; then
  CNAME_ONLY=false
  PROXY_ONLY=false
fi

# Check if source is required but missing
if [[ ("${PROXY_ONLY}" == true || "${CNAME_ONLY}" == false) && -z "${SOURCE}" ]]; then
  log_error "Error: Source IP:PORT (--source) is required for proxy configuration"
  usage
fi

# Full domain name
FQDN="${SUBDOMAIN}.${DOMAIN_SUFFIX}"

# If source is provided, validate it and extract IP and PORT
if [[ -n "${SOURCE}" ]]; then
  # Validate source format (IP:PORT)
  if ! [[ "${SOURCE}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+$ ]]; then
    log_error "Invalid source format. Must be IP:PORT (e.g., 192.168.1.50:3456)"
    exit 1
  fi

  # Extract IP and PORT from source
  IP=$(echo "${SOURCE}" | cut -d':' -f1)
  PORT=$(echo "${SOURCE}" | cut -d':' -f2)
fi

log_info "🚀 Starting configuration for ${FQDN}"
[[ -n "${SOURCE}" ]] && log_info "🔌 Backend service: ${SOURCE}"

# Execute operations based on flags
EXIT_CODE=0

if [[ "${PROXY_ONLY}" == false ]]; then
  add_cname_record || EXIT_CODE=$?
fi

if [[ "${CNAME_ONLY}" == false ]]; then
  add_proxy_host || EXIT_CODE=$?
fi

# Final summary if everything succeeded
if [[ $EXIT_CODE -eq 0 ]]; then
  echo ""
  log_success "Configuration complete! 🎉"
  echo -e "${BLUE}📋 Summary:${NC}"
  echo -e "  • Domain: ${FQDN}"
  
  if [[ "${PROXY_ONLY}" == false ]]; then
    echo -e "  • CNAME points to: ${PROXY_TARGET}"
  fi
  
  if [[ "${CNAME_ONLY}" == false ]]; then
    echo -e "  • Backend service: ${IP}:${PORT}"
    echo -e "  • HTTPS: ✅ (Certificate ID: ${CERT_ID})"
    echo ""
    echo -e "🌐 Your service should be accessible at: https://${FQDN}"
  fi
else
  echo ""
  log_warning "⚠️ Not all operations completed successfully. Check errors above."
  if [[ "${DEBUG}" != "true" ]]; then
    echo -e "💡 Tip: Run with ${YELLOW}--debug${NC} flag for more detailed output"
  fi
fi

exit $EXIT_CODE
