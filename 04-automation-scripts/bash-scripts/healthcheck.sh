#!/usr/bin/env bash

#############################################
# Health Check Script for Services
# Usage: ./health-check.sh [options]
# Can be used in:
#   - K8s liveness/readiness probes
#   - Monitoring systems
#   - Load balancer health checks
#   - CI/CD pipelines
#############################################

set -euo pipefail

# Configuration
readonly SCRIPT_NAME=$(basename "$0")
readonly DEFAULT_TIMEOUT=10
readonly DEFAULT_RETRIES=3

# Exit codes
readonly EXIT_SUCCESS=0
readonly EXIT_FAILURE=1
readonly EXIT_WARNING=2

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

#############################################
# Configuration Variables
#############################################

SERVICE_URL="${SERVICE_URL:-http://localhost:8080}"
HEALTH_ENDPOINT="${HEALTH_ENDPOINT:-/health}"
TIMEOUT="${TIMEOUT:-${DEFAULT_TIMEOUT}}"
RETRIES="${RETRIES:-${DEFAULT_RETRIES}}"
EXPECTED_STATUS="${EXPECTED_STATUS:-200}"
CHECK_DATABASE="${CHECK_DATABASE:-false}"
CHECK_REDIS="${CHECK_REDIS:-false}"
CHECK_DISK="${CHECK_DISK:-false}"
DISK_THRESHOLD="${DISK_THRESHOLD:-85}"
CHECK_MEMORY="${CHECK_MEMORY:-false}"
MEMORY_THRESHOLD="${MEMORY_THRESHOLD:-90}"
VERBOSE="${VERBOSE:-false}"
JSON_OUTPUT="${JSON_OUTPUT:-false}"

#############################################
# Logging Functions
#############################################

log_info() {
    if [[ "${VERBOSE}" == "true" ]] || [[ "${JSON_OUTPUT}" == "false" ]]; then
        echo -e "${GREEN}[✓]${NC} $*"
    fi
}

log_warn() {
    if [[ "${JSON_OUTPUT}" == "false" ]]; then
        echo -e "${YELLOW}[!]${NC} $*" >&2
    fi
}

log_error() {
    if [[ "${JSON_OUTPUT}" == "false" ]]; then
        echo -e "${RED}[✗]${NC} $*" >&2
    fi
}

#############################################
# Health Check Functions
#############################################

check_http_endpoint() {
    local url="$1"
    local expected_status="$2"
    local timeout="$3"
    
    local response
    local http_code
    
    response=$(curl -s -w "\n%{http_code}" --max-time "${timeout}" "${url}" 2>/dev/null) || {
        log_error "Failed to connect to ${url}"
        return 1
    }
    
    http_code=$(echo "${response}" | tail -n1)
    
    if [[ "${http_code}" == "${expected_status}" ]]; then
        log_info "HTTP endpoint healthy: ${url} (${http_code})"
        return 0
    else
        log_error "HTTP endpoint unhealthy: ${url} (Expected: ${expected_status}, Got: ${http_code})"
        return 1
    fi
}

check_service_port() {
    local host="$1"
    local port="$2"
    local timeout="$3"
    
    if timeout "${timeout}" bash -c "cat < /dev/null > /dev/tcp/${host}/${port}" 2>/dev/null; then
        log_info "Port ${port} is open on ${host}"
        return 0
    else
        log_error "Port ${port} is not accessible on ${host}"
        return 1
    fi
}

check_process() {
    local process_name="$1"
    
    if pgrep -x "${process_name}" > /dev/null; then
        log_info "Process '${process_name}' is running"
        return 0
    else
        log_error "Process '${process_name}' is not running"
        return 1
    fi
}

check_systemd_service() {
    local service_name="$1"
    
    if systemctl is-active --quiet "${service_name}"; then
        log_info "Systemd service '${service_name}' is active"
        return 0
    else
        log_error "Systemd service '${service_name}' is not active"
        systemctl status "${service_name}" --no-pager || true
        return 1
    fi
}

check_database() {
    local db_type="${DB_TYPE:-postgres}"
    local db_host="${DB_HOST:-localhost}"
    local db_port="${DB_PORT:-5432}"
    local db_name="${DB_NAME:-postgres}"
    local db_user="${DB_USER:-postgres}"
    
    case "${db_type}" in
        postgres)
            if command -v psql &> /dev/null; then
                if PGPASSWORD="${DB_PASSWORD}" psql -h "${db_host}" -p "${db_port}" -U "${db_user}" -d "${db_name}" -c "SELECT 1;" > /dev/null 2>&1; then
                    log_info "PostgreSQL database connection successful"
                    return 0
                else
                    log_error "PostgreSQL database connection failed"
                    return 1
                fi
            else
                log_warn "psql command not found, skipping database check"
                return 0
            fi
            ;;
        mysql)
            if command -v mysql &> /dev/null; then
                if mysql -h "${db_host}" -P "${db_port}" -u "${db_user}" -p"${DB_PASSWORD}" -e "SELECT 1;" > /dev/null 2>&1; then
                    log_info "MySQL database connection successful"
                    return 0
                else
                    log_error "MySQL database connection failed"
                    return 1
                fi
            else
                log_warn "mysql command not found, skipping database check"
                return 0
            fi
            ;;
        *)
            log_warn "Unknown database type: ${db_type}"
            return 0
            ;;
    esac
}

check_redis() {
    local redis_host="${REDIS_HOST:-localhost}"
    local redis_port="${REDIS_PORT:-6379}"
    
    if command -v redis-cli &> /dev/null; then
        if redis-cli -h "${redis_host}" -p "${redis_port}" ping > /dev/null 2>&1; then
            log_info "Redis connection successful"
            return 0
        else
            log_error "Redis connection failed"
            return 1
        fi
    else
        log_warn "redis-cli command not found, skipping Redis check"
        return 0
    fi
}

check_disk_space() {
    local threshold="$1"
    local mount_point="${MOUNT_POINT:-/}"
    
    local usage=$(df -h "${mount_point}" | awk 'NR==2 {print $5}' | sed 's/%//')
    
    if [[ ${usage} -lt ${threshold} ]]; then
        log_info "Disk space OK: ${usage}% used on ${mount_point}"
        return 0
    else
        log_error "Disk space critical: ${usage}% used on ${mount_point} (threshold: ${threshold}%)"
        return 1
    fi
}

check_memory_usage() {
    local threshold="$1"
    
    local usage=$(free | awk 'NR==2 {printf "%.0f", $3*100/$2}')
    
    if [[ ${usage} -lt ${threshold} ]]; then
        log_info "Memory usage OK: ${usage}%"
        return 0
    else
        log_error "Memory usage high: ${usage}% (threshold: ${threshold}%)"
        return 1
    fi
}

#############################################
# Main Health Check with Retries
#############################################

perform_health_checks() {
    local checks_failed=0
    local checks_warned=0
    
    # HTTP endpoint check (primary)
    local full_url="${SERVICE_URL}${HEALTH_ENDPOINT}"
    if ! check_http_endpoint "${full_url}" "${EXPECTED_STATUS}" "${TIMEOUT}"; then
        checks_failed=$((checks_failed + 1))
    fi
    
    # Optional: Database check
    if [[ "${CHECK_DATABASE}" == "true" ]]; then
        if ! check_database; then
            checks_failed=$((checks_failed + 1))
        fi
    fi
    
    # Optional: Redis check
    if [[ "${CHECK_REDIS}" == "true" ]]; then
        if ! check_redis; then
            checks_failed=$((checks_failed + 1))
        fi
    fi
    
    # Optional: Disk space check
    if [[ "${CHECK_DISK}" == "true" ]]; then
        if ! check_disk_space "${DISK_THRESHOLD}"; then
            checks_warned=$((checks_warned + 1))
        fi
    fi
    
    # Optional: Memory check
    if [[ "${CHECK_MEMORY}" == "true" ]]; then
        if ! check_memory_usage "${MEMORY_THRESHOLD}"; then
            checks_warned=$((checks_warned + 1))
        fi
    fi
    
    # Return appropriate exit code
    if [[ ${checks_failed} -gt 0 ]]; then
        return ${EXIT_FAILURE}
    elif [[ ${checks_warned} -gt 0 ]]; then
        return ${EXIT_WARNING}
    else
        return ${EXIT_SUCCESS}
    fi
}

output_json_result() {
    local status="$1"
    local message="$2"
    
    cat <<EOF
{
  "status": "${status}",
  "message": "${message}",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "service_url": "${SERVICE_URL}",
  "checks": {
    "http": true,
    "database": ${CHECK_DATABASE},
    "redis": ${CHECK_REDIS},
    "disk": ${CHECK_DISK},
    "memory": ${CHECK_MEMORY}
  }
}
EOF
}

#############################################
# Main Execution with Retry Logic
#############################################

main() {
    local attempt=1
    local result
    
    while [[ ${attempt} -le ${RETRIES} ]]; do
        if [[ "${VERBOSE}" == "true" && ${attempt} -gt 1 ]]; then
            log_info "Health check attempt ${attempt}/${RETRIES}"
        fi
        
        if perform_health_checks; then
            if [[ "${JSON_OUTPUT}" == "true" ]]; then
                output_json_result "healthy" "All health checks passed"
            else
                log_info "✓ Service is healthy"
            fi
            exit ${EXIT_SUCCESS}
        fi
        
        if [[ ${attempt} -lt ${RETRIES} ]]; then
            log_warn "Health check failed, retrying in 5 seconds..."
            sleep 5
        fi
        
        attempt=$((attempt + 1))
    done
    
    # All retries exhausted
    if [[ "${JSON_OUTPUT}" == "true" ]]; then
        output_json_result "unhealthy" "Health checks failed after ${RETRIES} attempts"
    else
        log_error "✗ Service is unhealthy after ${RETRIES} attempts"
    fi
    
    exit ${EXIT_FAILURE}
}

#############################################
# Usage Information
#############################################

usage() {
    cat <<EOF
Usage: ${SCRIPT_NAME} [OPTIONS]

Health check script for monitoring service status.

OPTIONS:
    -u, --url URL           Service URL (default: http://localhost:8080)
    -e, --endpoint PATH     Health endpoint path (default: /health)
    -t, --timeout SEC       Request timeout in seconds (default: 10)
    -r, --retries NUM       Number of retry attempts (default: 3)
    -s, --status CODE       Expected HTTP status code (default: 200)
    --check-db              Enable database connectivity check
    --check-redis           Enable Redis connectivity check
    --check-disk            Enable disk space check
    --check-memory          Enable memory usage check
    -v, --verbose           Enable verbose output
    -j, --json              Output results in JSON format
    -h, --help              Show this help message

EXAMPLES:
    # Basic health check
    ${SCRIPT_NAME}
    
    # Check with custom URL and endpoint
    ${SCRIPT_NAME} -u http://api.example.com -e /api/health
    
    # Full system check with JSON output
    ${SCRIPT_NAME} --check-db --check-redis --check-disk --check-memory -j
    
    # Kubernetes liveness probe
    ${SCRIPT_NAME} -u http://localhost:8080 -e /healthz -t 5 -r 1

ENVIRONMENT VARIABLES:
    SERVICE_URL             Override service URL
    HEALTH_ENDPOINT         Override health endpoint path
    TIMEOUT                 Override timeout
    RETRIES                 Override retry count
    DB_TYPE                 Database type (postgres, mysql)
    DB_HOST, DB_PORT        Database connection details
    DB_NAME, DB_USER        Database credentials
    DB_PASSWORD             Database password
    REDIS_HOST, REDIS_PORT  Redis connection details

EXIT CODES:
    0   All checks passed (healthy)
    1   One or more checks failed (unhealthy)
    2   Warning state (degraded but functional)
EOF
}

#############################################
# Parse Command Line Arguments
#############################################

while [[ $# -gt 0 ]]; do
    case $1 in
        -u|--url)
            SERVICE_URL="$2"
            shift 2
            ;;
        -e|--endpoint)
            HEALTH_ENDPOINT="$2"
            shift 2
            ;;
        -t|--timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        -r|--retries)
            RETRIES="$2"
            shift 2
            ;;
        -s|--status)
            EXPECTED_STATUS="$2"
            shift 2
            ;;
        --check-db)
            CHECK_DATABASE="true"
            shift
            ;;
        --check-redis)
            CHECK_REDIS="true"
            shift
            ;;
        --check-disk)
            CHECK_DISK="true"
            shift
            ;;
        --check-memory)
            CHECK_MEMORY="true"
            shift
            ;;
        -v|--verbose)
            VERBOSE="true"
            shift
            ;;
        -j|--json)
            JSON_OUTPUT="true"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Execute main function
main