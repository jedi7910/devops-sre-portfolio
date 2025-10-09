#!/usr/bin/env bash

#############################################
# Production Deployment Script with Rollback
# Usage: ./deploy.sh <environment> [version]
# Example: ./deploy.sh staging v1.2.3
#############################################

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_DIR="${SCRIPT_DIR}/logs"
readonly BACKUP_DIR="${SCRIPT_DIR}/backups"
readonly TIMESTAMP=$(date +%Y%m%d_%H%M%S)
readonly LOG_FILE="${LOG_DIR}/deploy_${TIMESTAMP}.log"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

# Deployment settings
DEPLOY_DIR="/var/www/app"
SERVICE_NAME="myapp"
MAX_RETRIES=3
HEALTH_CHECK_TIMEOUT=60

#############################################
# Logging Functions
#############################################

log() {
    echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "${LOG_FILE}"
}

log_info() {
    echo -e "${GREEN}[INFO]${NC} $*" | tee -a "${LOG_FILE}"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*" | tee -a "${LOG_FILE}"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" | tee -a "${LOG_FILE}"
}

#############################################
# Setup and Validation
#############################################

setup() {
    # Create necessary directories
    mkdir -p "${LOG_DIR}" "${BACKUP_DIR}"
    
    log_info "Starting deployment at ${TIMESTAMP}"
    log_info "Environment: ${ENVIRONMENT}"
    log_info "Version: ${VERSION}"
}

validate_environment() {
    local env=$1
    
    case "${env}" in
        dev|staging|production)
            log_info "Valid environment: ${env}"
            ;;
        *)
            log_error "Invalid environment: ${env}"
            log_error "Must be one of: dev, staging, production"
            exit 1
            ;;
    esac
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if running as correct user
    if [[ $(whoami) != "deploy" && $(whoami) != "root" ]]; then
        log_warn "Not running as deploy user. Some operations may fail."
    fi
    
    # Check required commands
    local required_commands=("systemctl" "rsync" "tar")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "${cmd}" &> /dev/null; then
            log_error "Required command not found: ${cmd}"
            exit 1
        fi
    done
    
    # Check if service exists
    if ! systemctl list-unit-files | grep -q "${SERVICE_NAME}"; then
        log_error "Service ${SERVICE_NAME} not found"
        exit 1
    fi
    
    log_info "Prerequisites check passed"
}

#############################################
# Backup Functions
#############################################

create_backup() {
    log_info "Creating backup of current deployment..."
    
    local backup_file="${BACKUP_DIR}/${SERVICE_NAME}_${TIMESTAMP}.tar.gz"
    
    if [[ -d "${DEPLOY_DIR}" ]]; then
        tar -czf "${backup_file}" -C "$(dirname "${DEPLOY_DIR}")" "$(basename "${DEPLOY_DIR}")" 2>> "${LOG_FILE}"
        
        if [[ $? -eq 0 ]]; then
            log_info "Backup created: ${backup_file}"
            echo "${backup_file}" > "${BACKUP_DIR}/latest_backup.txt"
            return 0
        else
            log_error "Backup creation failed"
            return 1
        fi
    else
        log_warn "Deploy directory does not exist. Skipping backup."
        return 0
    fi
}

restore_backup() {
    log_warn "Initiating rollback..."
    
    local latest_backup=$(cat "${BACKUP_DIR}/latest_backup.txt" 2>/dev/null)
    
    if [[ -z "${latest_backup}" || ! -f "${latest_backup}" ]]; then
        log_error "No backup found for rollback"
        return 1
    fi
    
    log_info "Restoring from backup: ${latest_backup}"
    
    # Stop service
    systemctl stop "${SERVICE_NAME}" || true
    
    # Remove current deployment
    rm -rf "${DEPLOY_DIR}"
    
    # Extract backup
    tar -xzf "${latest_backup}" -C "$(dirname "${DEPLOY_DIR}")" 2>> "${LOG_FILE}"
    
    if [[ $? -eq 0 ]]; then
        log_info "Backup restored successfully"
        return 0
    else
        log_error "Backup restoration failed"
        return 1
    fi
}

#############################################
# Deployment Functions
#############################################

stop_service() {
    log_info "Stopping service: ${SERVICE_NAME}"
    
    systemctl stop "${SERVICE_NAME}" || {
        log_error "Failed to stop service"
        return 1
    }
    
    sleep 2
    log_info "Service stopped"
}

deploy_application() {
    log_info "Deploying application version ${VERSION}..."
    
    # Example: Copy from build directory or pull from artifact store
    local source_dir="${SCRIPT_DIR}/builds/${VERSION}"
    
    if [[ ! -d "${source_dir}" ]]; then
        log_error "Source directory not found: ${source_dir}"
        return 1
    fi
    
    # Sync files
    rsync -av --delete "${source_dir}/" "${DEPLOY_DIR}/" >> "${LOG_FILE}" 2>&1
    
    if [[ $? -ne 0 ]]; then
        log_error "File sync failed"
        return 1
    fi
    
    # Set proper permissions
    chown -R www-data:www-data "${DEPLOY_DIR}" 2>> "${LOG_FILE}" || true
    chmod -R 755 "${DEPLOY_DIR}" 2>> "${LOG_FILE}" || true
    
    log_info "Application deployed successfully"
    return 0
}

start_service() {
    log_info "Starting service: ${SERVICE_NAME}"
    
    local retry_count=0
    
    while [[ ${retry_count} -lt ${MAX_RETRIES} ]]; do
        systemctl start "${SERVICE_NAME}"
        
        if [[ $? -eq 0 ]]; then
            sleep 3
            
            if systemctl is-active --quiet "${SERVICE_NAME}"; then
                log_info "Service started successfully"
                return 0
            fi
        fi
        
        retry_count=$((retry_count + 1))
        log_warn "Service start attempt ${retry_count} failed. Retrying..."
        sleep 5
    done
    
    log_error "Failed to start service after ${MAX_RETRIES} attempts"
    return 1
}

#############################################
# Health Check Functions
#############################################

perform_health_check() {
    log_info "Performing health check..."
    
    local health_url="http://localhost:8080/health"
    local elapsed=0
    
    while [[ ${elapsed} -lt ${HEALTH_CHECK_TIMEOUT} ]]; do
        if curl -sf "${health_url}" > /dev/null 2>&1; then
            log_info "Health check passed"
            return 0
        fi
        
        sleep 5
        elapsed=$((elapsed + 5))
        log_info "Waiting for service to be healthy... (${elapsed}s/${HEALTH_CHECK_TIMEOUT}s)"
    done
    
    log_error "Health check failed after ${HEALTH_CHECK_TIMEOUT} seconds"
    return 1
}

verify_deployment() {
    log_info "Verifying deployment..."
    
    # Check service status
    if ! systemctl is-active --quiet "${SERVICE_NAME}"; then
        log_error "Service is not running"
        return 1
    fi
    
    # Perform health check
    if ! perform_health_check; then
        return 1
    fi
    
    # Check log for errors (last 10 lines)
    if journalctl -u "${SERVICE_NAME}" -n 10 | grep -i "error" > /dev/null; then
        log_warn "Errors detected in recent logs"
    fi
    
    log_info "Deployment verification passed"
    return 0
}

#############################################
# Cleanup Functions
#############################################

cleanup_old_backups() {
    log_info "Cleaning up old backups (keeping last 5)..."
    
    cd "${BACKUP_DIR}" || return
    
    ls -t ${SERVICE_NAME}_*.tar.gz 2>/dev/null | tail -n +6 | xargs -r rm -f
    
    log_info "Cleanup completed"
}

#############################################
# Main Execution Flow
#############################################

main() {
    # Validate arguments
    if [[ $# -lt 1 ]]; then
        echo "Usage: $0 <environment> [version]"
        echo "Example: $0 staging v1.2.3"
        exit 1
    fi
    
    readonly ENVIRONMENT=$1
    readonly VERSION=${2:-$(date +%Y%m%d_%H%M%S)}
    
    # Setup
    setup
    validate_environment "${ENVIRONMENT}"
    check_prerequisites
    
    # Create backup before deployment
    if ! create_backup; then
        log_error "Backup creation failed. Aborting deployment."
        exit 1
    fi
    
    # Deploy
    if ! stop_service; then
        log_error "Failed to stop service"
        exit 1
    fi
    
    if ! deploy_application; then
        log_error "Deployment failed. Initiating rollback..."
        restore_backup
        start_service
        exit 1
    fi
    
    if ! start_service; then
        log_error "Failed to start service. Initiating rollback..."
        restore_backup
        start_service
        exit 1
    fi
    
    # Verify
    if ! verify_deployment; then
        log_error "Deployment verification failed. Initiating rollback..."
        stop_service
        restore_backup
        start_service
        exit 1
    fi
    
    # Success
    log_info "Deployment completed successfully!"
    log_info "Version ${VERSION} is now running in ${ENVIRONMENT}"
    
    # Cleanup
    cleanup_old_backups
    
    # Send notification (optional)
    # ./notify.sh "Deployment successful: ${VERSION} to ${ENVIRONMENT}"
}

# Trap errors and perform rollback
trap 'log_error "Deployment failed with error. Check logs at ${LOG_FILE}"; exit 1' ERR

# Execute main function
main "$@"