#!/usr/bin/env python3

################################################
# Backup Script for Application Data and Database
# Usage: python3 backup.py <backup_type>
# Example: python3 backup.py full
################################################

import os
import shutil
from datetime import datetime
import subprocess


# Configuration
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
LOG_DIR = os.path.join(SCRIPT_DIR, "logs")
BACKUP_DIR = os.path.join(SCRIPT_DIR, "backups")
TIMESTAMP = datetime.now().strftime("%Y%m%d%H")
LOG_FILE = os.path.join(LOG_DIR, f"backup{TIMESTAMP}.log")

# Backup type argument
BACKUP_TYPE = sys.argv[1] if len(sys.argv) > 1 else "FULL"

# Make sure directories exist
os.makedirs(LOG_DIR, exist_ok=True)
os.makedirs(BACKUP_DIR, exist_ok=True)

# Colors for output
RED = "\033[0;31m"
GREEN = "\033[0;32m"
YELLOW = "\033[1;33m"
NC = "\033[0m"

# Backup Settings
DB_TYPE = os.getenv("DB_TYPE", "")
DB_NAME = os.getenv("DB_NAME", "")
DB_USER = os.getenv("DB_USER", "")
DB_PASSWORD = os.getenv("DB_PASSWORD","")
DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = os.getenv("DB_PORT", "")
APP_DATA_DIR = os.getenv("APP_DATA_DIR", "")
MAX_BACKUPS = int(os.getenv("MAX_BACKUPS", 5))
