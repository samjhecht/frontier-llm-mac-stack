# Step 12: Backup Strategy Implementation

## Overview
Implement a comprehensive backup strategy for the LLM stack, including model files, configurations, and monitoring data. This ensures quick recovery in case of failures.

## Tasks
1. Enhance backup script with validation
2. Implement incremental backups for models
3. Create restore procedures
4. Set up automated backup scheduling
5. Implement backup testing and verification

## Implementation Details

### 1. Enhanced Backup Script
Update `scripts/backup/backup-llm-stack.sh`:
```bash
#!/bin/bash
set -euo pipefail

# Backup configuration
BACKUP_ROOT="${BACKUP_ROOT:-/Volumes/Backup/frontier-llm}"
BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="$BACKUP_ROOT/$BACKUP_DATE"
BACKUP_LOG="$BACKUP_DIR/backup.log"

# Backup components
COMPONENTS=(
    "config:./config:Configuration files"
    "env:./.env:Environment settings"
    "compose:./docker-compose.*:Docker compose files"
    "scripts:./scripts:Automation scripts"
    "models:$HOME/ollama-models:Model files (large)"
    "prometheus:./data/prometheus:Metrics data"
    "grafana:./data/grafana:Dashboard data"
)

# Initialize backup
initialize_backup() {
    echo "=== Frontier LLM Stack Backup ==="
    echo "Backup date: $BACKUP_DATE"
    
    # Check backup destination
    if [[ ! -d "$(dirname "$BACKUP_ROOT")" ]]; then
        echo "ERROR: Backup destination not available"
        exit 1
    fi
    
    # Create backup directory
    mkdir -p "$BACKUP_DIR"
    
    # Start logging
    exec 1> >(tee -a "$BACKUP_LOG")
    exec 2>&1
}

# Backup function with progress
backup_component() {
    local name="$1"
    local source="$2"
    local description="$3"
    
    echo -n "Backing up $description... "
    
    if [[ ! -e "$source" ]]; then
        echo "SKIPPED (not found)"
        return
    fi
    
    # Calculate size
    local size=$(du -sh "$source" 2>/dev/null | cut -f1)
    echo -n "($size) "
    
    # Perform backup
    if rsync -av --progress "$source" "$BACKUP_DIR/$name/" > /dev/null 2>&1; then
        echo "✓"
    else
        echo "✗ FAILED"
        return 1
    fi
}

# Model incremental backup
backup_models_incremental() {
    echo "Performing incremental model backup..."
    
    # Find latest backup
    local latest_backup=$(ls -1d "$BACKUP_ROOT"/*/models 2>/dev/null | tail -1)
    
    if [[ -n "$latest_backup" ]]; then
        echo "Using incremental backup from: $(dirname "$latest_backup")"
        rsync -av --link-dest="$latest_backup" \
            "$HOME/ollama-models/" "$BACKUP_DIR/models/"
    else
        echo "No previous backup found, performing full backup"
        rsync -av "$HOME/ollama-models/" "$BACKUP_DIR/models/"
    fi
}

# Backup validation
validate_backup() {
    echo -e "\n=== Validating Backup ==="
    
    local errors=0
    
    # Check critical files
    for file in "config/prometheus/prometheus.yml" "docker-compose.yml" ".env"; do
        if [[ ! -f "$BACKUP_DIR/$file" ]]; then
            echo "✗ Missing: $file"
            ((errors++))
        else
            echo "✓ Found: $file"
        fi
    done
    
    # Check model files
    if [[ -d "$BACKUP_DIR/models" ]]; then
        local model_count=$(find "$BACKUP_DIR/models" -name "*.bin" -o -name "*.gguf" | wc -l)
        echo "✓ Model files: $model_count"
    else
        echo "✗ No model files backed up"
        ((errors++))
    fi
    
    return $errors
}

# Main backup process
main() {
    initialize_backup
    
    # Stop services for consistent backup
    echo "Stopping services for consistent backup..."
    docker compose stop
    
    # Backup each component
    for component in "${COMPONENTS[@]}"; do
        IFS=':' read -r name source description <<< "$component"
        backup_component "$name" "$source" "$description"
    done
    
    # Special handling for models
    backup_models_incremental
    
    # Export Docker volumes
    echo "Exporting Docker volumes..."
    docker run --rm -v prometheus-data:/data -v "$BACKUP_DIR/volumes":/backup \
        alpine tar czf /backup/prometheus-data.tar.gz -C /data .
    
    # Restart services
    echo "Restarting services..."
    docker compose up -d
    
    # Validate backup
    if validate_backup; then
        echo -e "\n✓ Backup completed successfully"
        echo "Location: $BACKUP_DIR"
    else
        echo -e "\n✗ Backup completed with errors"
        exit 1
    fi
    
    # Cleanup old backups (keep last 7)
    cleanup_old_backups
}

# Cleanup old backups
cleanup_old_backups() {
    echo -e "\n=== Cleaning Old Backups ==="
    
    local backups=($(ls -1d "$BACKUP_ROOT"/20* 2>/dev/null | sort -r))
    local keep=7
    
    if [[ ${#backups[@]} -gt $keep ]]; then
        for ((i=$keep; i<${#backups[@]}; i++)); do
            echo "Removing old backup: ${backups[$i]}"
            rm -rf "${backups[$i]}"
        done
    fi
}

# Run backup
main "$@"
```

### 2. Restore Script
Create `scripts/backup/restore-llm-stack.sh`:
```bash
#!/bin/bash
set -euo pipefail

# Restore from backup
BACKUP_ROOT="${BACKUP_ROOT:-/Volumes/Backup/frontier-llm}"

echo "=== Frontier LLM Stack Restore ==="

# List available backups
echo "Available backups:"
ls -1d "$BACKUP_ROOT"/20* 2>/dev/null | sort -r | head -10

# Select backup
read -p "Enter backup date to restore (YYYYMMDD_HHMMSS): " BACKUP_DATE
BACKUP_DIR="$BACKUP_ROOT/$BACKUP_DATE"

if [[ ! -d "$BACKUP_DIR" ]]; then
    echo "ERROR: Backup not found: $BACKUP_DIR"
    exit 1
fi

# Confirm restore
echo "This will restore from: $BACKUP_DIR"
read -p "Continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
fi

# Stop services
docker compose down

# Restore files
echo "Restoring configuration..."
rsync -av "$BACKUP_DIR/config/" ./config/
rsync -av "$BACKUP_DIR/env/.env" ./.env
rsync -av "$BACKUP_DIR/compose/" ./

echo "Restoring models..."
rsync -av "$BACKUP_DIR/models/" "$HOME/ollama-models/"

# Restore Docker volumes
echo "Restoring Docker volumes..."
docker run --rm -v prometheus-data:/data -v "$BACKUP_DIR/volumes":/backup \
    alpine tar xzf /backup/prometheus-data.tar.gz -C /data

# Start services
docker compose up -d

echo "✓ Restore completed"
```

### 3. Automated Backup Scheduling
Create `scripts/backup/setup-backup-schedule.sh`:
```bash
#!/bin/bash

# Setup automated backups via cron
SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)/backup-llm-stack.sh"

# Create cron job
(crontab -l 2>/dev/null | grep -v "backup-llm-stack.sh"; \
 echo "0 2 * * * cd $(pwd) && $SCRIPT_PATH >> logs/backup.log 2>&1") | crontab -

echo "✓ Daily backup scheduled at 2 AM"
echo "View schedule: crontab -l"
echo "Logs: logs/backup.log"
```

### 4. Backup Testing
Create `scripts/backup/test-backup-restore.sh`:
```bash
#!/bin/bash
# Test backup and restore process

echo "=== Testing Backup/Restore Process ==="

# Create test backup
BACKUP_ROOT="/tmp/test-backup" ./scripts/backup/backup-llm-stack.sh

# Modify something
echo "test_modification" >> ./config/test.txt

# Restore from backup
BACKUP_ROOT="/tmp/test-backup" ./scripts/backup/restore-llm-stack.sh

# Verify restore
if [[ ! -f ./config/test.txt ]] || grep -q "test_modification" ./config/test.txt; then
    echo "✗ Restore test failed"
    exit 1
fi

echo "✓ Backup/restore test passed"
```

## Dependencies
- All services configured and running
- Backup destination available
- Sufficient storage space

## Success Criteria
- Backups complete without errors
- Incremental model backups work
- Restore process recovers full stack
- Automated scheduling works
- Old backups cleaned up properly

## Testing
```bash
# Test backup
./scripts/backup/backup-llm-stack.sh --dry-run

# Test restore
./scripts/backup/test-backup-restore.sh

# Verify schedule
crontab -l | grep backup
```

## Notes
- Model backups can be large (30-500GB)
- Consider network attached storage for backups
- Test restore procedure regularly
- Monitor backup job success/failure