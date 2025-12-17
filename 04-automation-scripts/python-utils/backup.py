#!/usr/bin/env python3
import os
import sys
import argparse
import subprocess
import tarfile
import hashlib
from datetime import datetime
import logging
import shutil

# -----------------------
# Logging setup
# -----------------------
SCRIPT_DIR = os.path.dirname(os.path.realpath(__file__))
LOG_DIR = os.path.join(SCRIPT_DIR, "logs")
BACKUP_DIR = os.path.join(SCRIPT_DIR, "backups")
os.makedirs(LOG_DIR, exist_ok=True)
os.makedirs(BACKUP_DIR, exist_ok=True)
TIMESTAMP = datetime.now().strftime("%Y%m%d_%H%M%S")
LOG_FILE = os.path.join(LOG_DIR, f"backup_{TIMESTAMP}.log")

logging.basicConfig(
    level=logging.INFO,
    format="[%(asctime)s] %(levelname)s: %(message)s",
    handlers=[
        logging.FileHandler(LOG_FILE),
        logging.StreamHandler(sys.stdout)
    ]
)

# -----------------------
# Argument parsing
# -----------------------
def parse_arguments():
    parser = argparse.ArgumentParser(description="Backup script for app data and DB")
    parser.add_argument("--db-type", choices=["mysql", "postgres"])
    parser.add_argument("--db-name")
    parser.add_argument("--db-user")
    parser.add_argument("--db-password")
    parser.add_argument("--db-host", default="localhost")
    parser.add_argument("--db-port", type=int)
    parser.add_argument("--app-data-dir")
    parser.add_argument("--s3-bucket")
    parser.add_argument("--backup-name")
    parser.add_argument("backup_type", nargs="?", default="full", choices=["full","incremental"])
    return parser.parse_args()

# -----------------------
# Backup verification
# -----------------------
def verify_backup(file_path):
    if not os.path.exists(file_path):
        logging.error(f"Backup file does not exist: {file_path}")
        return False
    if os.path.getsize(file_path) == 0:
        logging.error(f"Backup file is empty: {file_path}")
        return False
    # checksum
    checksum_file = file_path + ".sha256"
    with open(file_path, "rb") as f, open(checksum_file, "w") as csum:
        sha256 = hashlib.sha256(f.read()).hexdigest()
        csum.write(f"{sha256}  {os.path.basename(file_path)}\n")
    logging.info(f"Backup verified: {file_path}")
    return True

# -----------------------
# Database backup
# -----------------------
def backup_database(args):
    if not args.db_type:
        logging.warning("DB_TYPE not set; skipping database backup.")
        return None

    db_port = args.db_port or (3306 if args.db_type == "mysql" else 5432)
    db_backup_file = os.path.join(BACKUP_DIR, f"db_{args.db_name}_{TIMESTAMP}.sql.gz")

    logging.info(f"Backing up database '{args.db_name}'...")

    try:
        if args.db_type == "mysql":
            cmd = [
                "mysqldump",
                "-h", args.db_host,
                "-P", str(db_port),
                "-u", args.db_user,
                f"-p{args.db_password}",
                args.db_name
            ]
            with open(db_backup_file, "wb") as f:
                subprocess.run(cmd, stdout=subprocess.PIPE, check=True)
                # gzip compression
                subprocess.run(["gzip", "-f", db_backup_file], check=True)
        elif args.db_type == "postgres":
            env = os.environ.copy()
            env["PGPASSWORD"] = args.db_password
            cmd = [
                "pg_dump",
                "-h", args.db_host,
                "-p", str(db_port),
                "-U", args.db_user,
                "-F", "c",
                args.db_name
            ]
            with open(db_backup_file, "wb") as f:
                subprocess.run(cmd, env=env, check=True)
        else:
            logging.error(f"Unsupported DB_TYPE: {args.db_type}")
            return None
    except subprocess.CalledProcessError:
        logging.error("Database backup failed.")
        return None

    logging.info(f"Database backup completed: {db_backup_file}")
    return db_backup_file

# -----------------------
# Application data backup
# -----------------------
def backup_app_data(args):
    if not args.app_data_dir:
        logging.warning("APP_DATA_DIR not set; skipping app data backup.")
        return None

    if not os.path.exists(args.app_data_dir) or not os.access(args.app_data_dir, os.R_OK):
        logging.error(f"Cannot read application data directory: {args.app_data_dir}")
        return None

    app_backup_file = os.path.join(BACKUP_DIR, f"app_data_{TIMESTAMP}.tar.gz")
    logging.info(f"Backing up application data from '{args.app_data_dir}'...")
    with tarfile.open(app_backup_file, "w:gz") as tar:
        tar.add(args.app_data_dir, arcname=os.path.basename(args.app_data_dir))

    logging.info(f"Application data backup completed: {app_backup_file}")
    return app_backup_file

# -----------------------
# Rotate old backups
# -----------------------
def rotate_backups(max_backups=5):
    files = sorted([os.path.join(BACKUP_DIR, f) for f in os.listdir(BACKUP_DIR) 
                    if f.endswith((".tar.gz", ".sql.gz"))])
    if len(files) > max_backups:
        for old in files[:-max_backups]:
            logging.info(f"Deleting old backup: {old}")
            os.remove(old)

# -----------------------
# Optional: Upload to S3
# -----------------------
def upload_to_s3(file_path, bucket):
    if not bucket:
        logging.info("S3_BUCKET not set; skipping S3 upload.")
        return

    try:
        import boto3
        s3 = boto3.client("s3")
        s3.upload_file(file_path, bucket, os.path.basename(file_path))
        logging.info(f"S3 upload successful: {file_path}")
    except Exception as e:
        logging.warning(f"S3 upload failed: {e}")

# -----------------------
# Main entry point
# -----------------------
def main():
    args = parse_arguments()

    if not args.db_type and not args.app_data_dir:
        logging.error("Nothing to back up. Set APP_DATA_DIR or DB_TYPE.")
        sys.exit(1)

    db_file = backup_database(args)
    app_file = backup_app_data(args)

    if db_file:
        verify_backup(db_file)
        if args.s3_bucket:
            upload_to_s3(db_file, args.s3_bucket)
    if app_file:
        verify_backup(app_file)
        if args.s3_bucket:
            upload_to_s3(app_file, args.s3_bucket)

    rotate_backups()
    logging.info("Backup process completed successfully.")

if __name__ == "__main__":
    main()
