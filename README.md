# Database Script Helper

A Bash script for restoring PostgreSQL database backups with comprehensive logging and error handling.

## Overview

This script provides automated database restoration functionality with the following features:
- Environment variable configuration
- Database connection validation
- Schema and data restoration
- Sequence restoration
- Comprehensive logging
- Table skipping capability
- Progress tracking

## Configuration Variables

- `BACKUP_DIR`: Directory containing the backup files
- `HOST`: Database host (default: localhost)
- `PGPASSWORD`: Database password
- `USER`: Database username (default: postgres)
- `PORT`: Database port (default: 5432)
- `DB_NAME`: Database name (default: postgres)
- `SLEEP_TIME`: Delay between operations in seconds (default: 5)
- `SKIP_TABLES`: Array of table names to skip during restoration

## Usage

1. Set up environment variables in `.env` file or export them directly
2. Ensure backup directory is accessible
3. Run the script: `./lam_gi_day.sh`

## Execution Flow

1. Load environment variables
2. Check database connection
3. Get list of tables and sequences from backup
4. Restore database schema
5. Restore table data
6. Restore sequence values

## Logging

All operations are logged to timestamped log files in the `./log/` directory with format: `{HOST}-{DB_NAME}-{YYYYMMDD}.log`
