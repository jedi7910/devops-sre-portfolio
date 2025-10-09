#!/usr/bin/env bash

#############################################
# Backup Script for Application Data and Database
# Usage: ./backup.sh <backup_type>
# Example: ./backup.sh full
#############################################

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_DIR="${SCRIPT_DIR}/logs"
readonly BACKUP_DIR="${SCRIPT_DIR}/backups"
readonly TIMESTAMP=$(date +%Y%m%d_%H%M%S)
readonly LOG_FILE="${LOG_DIR}/backup_${TIMESTAMP}.log"
readonly BACKUP_TYPE="${1:-full}"  # full or incremental

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

# Backup settings
DB_TYPE="${DB_TYPE:-}"  # mysql or postgres
DB_NAME="${DB_NAME:-}"
DB_USER="${DB_USER:-}"
DB_PASSWORD="${DB_PASSWORD:-}" # never have a default password in production
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-}"
APP_DATA_DIR="${APP_DATA_DIR:-}"    # Application data to backup (optional)
MAX_BACKUPS="${MAX_BACKUPS:-5}"     # Number of backups to keep
S3_BUCKET="${S3_BUCKET:-}"          # Optional S3 upload
BACKUP_NAME="${BACKUP_NAME:-}"      # Optional custom backup name

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --db-type)
                DB_TYPE="$2"
                shift 2
                ;;
            --db-name)
                DB_NAME="$2"
                shift 2
                ;;
            --db-user)
                DB_USER="$2"
                shift 2
                ;;
            --db-password)
                DB_PASSWORD="$2"
                shift 2
                ;;
            --db-host)
                DB_HOST="$2"
                shift 2
                ;;
            --db-port)
                DB_PORT="$2"
                shift 2
                ;;
            --app-data-dir)
                APP_DATA_DIR="$2"
                shift 2
                ;;
            --s3-bucket)
                S3_BUCKET="$2"
                shift 2
                ;;
            --backup-name)
                BACKUP_NAME="$2"
                shift 2
                ;;
            --help)
                show_usage
                exit 0
                ;;   
            *)
                echo "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

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

    log_info "Starting backup at ${TIMESTAMP}"
    log_info "Backup type: ${BACKUP_TYPE}"
}


###############################################
# 1. Check: Is ANYTHING being backed up?
#    └─ If NO → Error and exit
#    └─ If YES → Continue

# 2. Check: Is DB_TYPE set?
#    └─ If YES → Validate database fields (DB_NAME, DB_USER, etc.)
#               └─ Then set DB_PORT based on type
#    └─ If NO → Skip database validation (that's OK!)

# 3. Done validating

validate_config() {
    log_info "Validating configuration..."

    if [[ -z "${APP_DATA_DIR}" && -z "${DB_TYPE}" ]]; then
        log_error "Nothing to back up. Set APP_DATA_DIR or DB_TYPE."
        exit 1
    fi

    if [[ -n "${DB_TYPE}" ]]; then
        if [[ -z "${DB_NAME}" || -z "${DB_USER}" || -z "${DB_PASSWORD}" ]]; then
            log_error "Database fields DB_NAME, DB_USER, and DB_PASSWORD must be set when DB_TYPE is specified."
            exit 1
        fi

        case "${DB_TYPE}" in
            mysql)
                DB_PORT="${DB_PORT:-3306}"
                ;;
            postgres)
                DB_PORT="${DB_PORT:-5432}"
                ;;
            *)
                log_error "Unsupported DB_TYPE: ${DB_TYPE}. Must be 'mysql' or 'postgres'."
                exit 1
                ;;
        esac

        log_info "Database configuration validated for ${DB_TYPE}."
    else
        log_info "No database backup configured; skipping database validation."
    fi

    if [[ -n "${APP_DATA_DIR}" && ! -d "${APP_DATA_DIR}" ]]; then
        log_error "Application data directory does not exist: ${APP_DATA_DIR}"
        exit 1
    fi

    if [[ -n "${APP_DATA_DIR}" && ! -r "${APP_DATA_DIR}" ]]; then
    log_error "Cannot read application data directory: ${APP_DATA_DIR}"
    exit 1
fi

    log_info "Configuration validation completed."
}

#############################################
# backup_database: Backup the database based on DB_TYPE
#############################################
# Check which DB_TYPE
# Use pg_dump or mysqldump
# Pipe to gzip
# Save to ${BACKUP_DIR}/db_${DB_NAME}_${TIMESTAMP}.sql.gz
# Return the filename (you'll need this for verification)
backup_database() {
    if [[ -z "${DB_TYPE}" ]]; then
        log_warn "DB_TYPE not set; skipping database backup."
        return 0
    fi

    local db_backup_file="${BACKUP_DIR}/db_${DB_NAME}_${TIMESTAMP}.sql.gz"

    log_info "Backing up database '${DB_NAME}'..."

    case "${DB_TYPE}" in
        mysql)
            mysqldump -h "${DB_HOST}" -P "${DB_PORT}" -u "${DB_USER}" -p"${DB_PASSWORD}" "${DB_NAME}" | gzip > "${db_backup_file}"
            ;;
        postgres)
            PGPASSWORD="${DB_PASSWORD}" pg_dump -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -F c "${DB_NAME}" > "${db_backup_file}"
            ;;
        *)
            log_error "Unsupported DB_TYPE: ${DB_TYPE}"
            return 1
            ;;
    esac

    if [[ $? -ne 0 ]]; then
        log_error "Database backup failed."
        return 1
    fi

    log_info "Database backup completed: ${db_backup_file}"
    echo "${db_backup_file}"
}

#############################################
# Backup Application Data
#############################################
backup_app_data() {
    if [[ -z "${APP_DATA_DIR}" ]]; then
        log_warn "APP_DATA_DIR not set; skipping application data backup."
        return 0
    fi
    local app_backup_file="${BACKUP_DIR}/app_data_${TIMESTAMP}.tar.gz"
    log_info "Backing up application data from '${APP_DATA_DIR}'..."
    tar -czf "${app_backup_file}" -C "$(dirname "${APP_DATA_DIR}")" "$(basename "${APP_DATA_DIR}")"
    if [[ $? -ne 0 ]]; then
        log_error "Application data backup failed."
        return 1
    fi
    log_info "Application data backup completed: ${app_backup_file}"
    echo "${app_backup_file}"
}

#############################################
# Verify Backups
verify_backup() {
    local backup_file="$1"
    
    # Check if file exists
    if [[ ! -f "${backup_file}" ]]; then
        log_error "Backup file does not exist: ${backup_file}"
        return 1
    fi
    
    # Check if file size > 0
    if [[ ! -s "${backup_file}" ]]; then
        log_error "Backup file is empty: ${backup_file}"
        return 1
    fi
    
    # Create checksum
    local checksum_file="${backup_file}.sha256"
    sha256sum "${backup_file}" > "${checksum_file}"
    if [[ $? -ne 0 ]]; then
        log_error "Failed to create checksum for: ${backup_file}"
        return 1
    fi
    
    log_info "Backup verified: ${backup_file}"
    return 0
}

#############################################
# Rotate Backups
#############################################
rotate_backups() {
    log_info "Rotating backups..."
    local backup_count=$(find "${BACKUP_DIR}" -maxdepth 1 -type f \( -name "*.tar.gz" -o -name "*.sql.gz" | wc -l \))
    if [[ ${backup_count} -gt ${MAX_BACKUPS} ]]; then
        local backups_to_delete=$(find "${BACKUP_DIR}" -maxdepth 1 -type f -name "*.tar.gz" -o -name "*.sql.gz" | sort | head -n $((backup_count - MAX_BACKUPS)))
        for backup in ${backups_to_delete}; do
            log_info "Deleting old backup: ${backup}"
            rm "${backup}"
        done
    fi
    log_info "Backup rotation completed."
}

#############################################
# Show Usage
#############################################
show_usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --db-type <mysql|postgres>       Type of database to back up"
    echo "  --db-name <name>                 Name of the database"
    echo "  --db-user <user>                 Database user"
    echo "  --db-password <password>         Database password"
    echo "  --db-host <host>                 Database host (default: localhost)"
    echo "  --db-port <port>                 Database port (default: 3306 for MySQL, 5432 for Postgres)"
    echo "  --app-data-dir <path>            Directory of application data to back up"
    echo "  --s3-bucket <bucket-name>        Optional S3 bucket to upload backups"
    echo "  --backup-name <name>             Optional custom backup name"
    echo "  --help                           Show this help message"
    echo ""
    echo "Example:"
    echo "  $0 --db-type mysql --db-name mydb --db-user user --db-password pass --app-data-dir /var/www/data"
}

###############################################
# Upload to S3 (optional)
###############################################
upload_to_s3() {
    local backup_file="$1"
    
    if [[ -z "${S3_BUCKET}" ]]; then
        log_info "S3_BUCKET not set; skipping S3 upload."
        return 0
    fi
    
    if ! command -v aws &> /dev/null; then
        log_warn "AWS CLI not installed; skipping S3 upload."
        return 0
    fi
    
    log_info "Uploading to S3: s3://${S3_BUCKET}/$(basename ${backup_file})"
    
    aws s3 cp "${backup_file}" "s3://${S3_BUCKET}/" 2>> "${LOG_FILE}"
    
    if [[ $? -eq 0 ]]; then
        log_info "S3 upload successful"
        return 0
    else
        log_error "S3 upload failed"
        return 1
    fi
}


##############################################
# main entry point
##############################################
# Call setup()
# Call parse_arguments "$@"
# Call validate_config()
# If DB_TYPE set → Call backup_database()
# If APP_DATA_DIR set → Call backup_app_data()
# Call verify_backup() for each backup created
# Call cleanup_old_backups()
# Log completion

main() {
    setup
    parse_arguments "$@"
    validate_config

    local db_backup_file=""
    local app_backup_file=""

    if [[ -n "${DB_TYPE}" ]]; then
        db_backup_file=$(backup_database)
        if [[ $? -ne 0 ]]; then
            log_error "Database backup failed. Aborting."
            exit 1
        fi
        verify_backup "${db_backup_file}"
        if [[ $? -ne 0 ]]; then
            log_error "Database backup verification failed. Aborting."
            exit 1
        fi
        if [[ -n "${S3_BUCKET}" ]]; then
            upload_to_s3 "${db_backup_file}"
            upload_to_s3 "${app_backup_file}"
            if [[ $? -ne 0 ]]; then
                log_warn "S3 upload for database backup failed."
            fi
        fi
    fi

    if [[ -n "${APP_DATA_DIR}" ]]; then
        app_backup_file=$(backup_app_data)
        if [[ $? -ne 0 ]]; then
            log_error "Application data backup failed. Aborting."
            exit 1
        fi
        verify_backup "${app_backup_file}"
        if [[ $? -ne 0 ]]; then
            log_error "Application data backup verification failed. Aborting."
            exit 1
        fi
    fi

    rotate_backups

    log_info "Backup process completed successfully."
}

main "$@"