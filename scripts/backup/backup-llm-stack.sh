#!/bin/bash
set -euo pipefail

# backup-llm-stack.sh - Comprehensive backup solution for the LLM stack
# Backs up models, configurations, and data with versioning

echo "=== Frontier LLM Stack Backup Tool ==="

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
BACKUP_ROOT="${BACKUP_ROOT:-/Volumes/Backup/frontier-llm-backups}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="${BACKUP_ROOT}/${TIMESTAMP}"
RETENTION_DAYS="${RETENTION_DAYS:-30}"
DRY_RUN=false
COMPRESSION="gzip"

# Function to print colored output
print_status() { echo -e "${GREEN}[INFO]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }
print_header() { echo -e "\n${BLUE}=== $1 ===${NC}\n"; }

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            print_warning "DRY RUN MODE - No actual backups will be created"
            shift
            ;;
        --backup-dir)
            BACKUP_ROOT="$2"
            BACKUP_DIR="${BACKUP_ROOT}/${TIMESTAMP}"
            shift 2
            ;;
        --compression)
            COMPRESSION="$2"
            shift 2
            ;;
        --help)
            cat << EOF
Usage: $0 [OPTIONS]

Options:
  --dry-run         Show what would be backed up without actually doing it
  --backup-dir DIR  Specify backup directory (default: $BACKUP_ROOT)
  --compression     Compression type: gzip, bzip2, xz, none (default: gzip)
  --help           Show this help message

Examples:
  $0                                    # Regular backup
  $0 --dry-run                         # See what would be backed up
  $0 --backup-dir /path/to/backup      # Custom backup location
EOF
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Function to format bytes
format_bytes() {
    local bytes=$1
    if [[ $bytes -lt 1024 ]]; then
        echo "${bytes}B"
    elif [[ $bytes -lt 1048576 ]]; then
        echo "$((bytes / 1024))KB"
    elif [[ $bytes -lt 1073741824 ]]; then
        echo "$((bytes / 1048576))MB"
    else
        echo "$((bytes / 1073741824))GB"
    fi
}

# Function to calculate directory size
get_dir_size() {
    local dir=$1
    if [[ -d "$dir" ]]; then
        du -sk "$dir" 2>/dev/null | awk '{print $1 * 1024}'
    else
        echo 0
    fi
}

# Check available space
check_backup_space() {
    print_header "Checking Backup Requirements"
    
    # Calculate total size to backup
    total_size=0
    
    # Ollama models
    models_size=$(get_dir_size ~/ollama-models)
    total_size=$((total_size + models_size))
    print_status "Ollama models: $(format_bytes $models_size)"
    
    # Docker volumes (if using Docker)
    if command -v docker &> /dev/null && docker info &> /dev/null 2>&1; then
        docker_size=$(docker system df --format json | jq '.Volumes[0].Size' 2>/dev/null || echo 0)
        total_size=$((total_size + docker_size))
        print_status "Docker volumes: $(format_bytes $docker_size)"
    fi
    
    # Configuration files
    config_size=$((1048576 * 10)) # Estimate 10MB for configs
    total_size=$((total_size + config_size))
    
    print_status "Total backup size (uncompressed): $(format_bytes $total_size)"
    
    # Check destination space
    if [[ -d "$(dirname "$BACKUP_ROOT")" ]]; then
        available_space=$(df -k "$(dirname "$BACKUP_ROOT")" | awk 'NR==2 {print $4 * 1024}')
        print_status "Available space: $(format_bytes $available_space)"
        
        # Estimate compressed size (assume 50% compression ratio)
        estimated_backup_size=$((total_size / 2))
        
        if [[ $available_space -lt $estimated_backup_size ]]; then
            print_error "Insufficient space for backup"
            print_error "Required: $(format_bytes $estimated_backup_size), Available: $(format_bytes $available_space)"
            return 1
        fi
    else
        print_warning "Backup directory does not exist yet"
    fi
    
    return 0
}

# Backup Ollama models
backup_ollama_models() {
    print_header "Backing up Ollama Models"
    
    if [[ ! -d ~/ollama-models ]]; then
        print_warning "Ollama models directory not found"
        return 0
    fi
    
    local models_backup_dir="${BACKUP_DIR}/ollama-models"
    
    if [[ "$DRY_RUN" == true ]]; then
        print_status "[DRY RUN] Would create: $models_backup_dir"
        print_status "[DRY RUN] Would backup models from: ~/ollama-models"
        
        # List models
        if command -v ollama &> /dev/null; then
            ollama list 2>/dev/null || true
        fi
    else
        mkdir -p "$models_backup_dir"
        
        # Create models manifest
        if command -v ollama &> /dev/null; then
            ollama list > "${models_backup_dir}/models-manifest.txt" 2>/dev/null || true
        fi
        
        # Backup model files
        print_status "Copying model files... This may take a while"
        rsync -av --progress ~/ollama-models/ "$models_backup_dir/" 2>&1 | \
            grep -E '(^sending|to-check|%|$)' || true
        
        print_status "Models backed up to: $models_backup_dir"
    fi
}

# Backup Docker volumes
backup_docker_volumes() {
    print_header "Backing up Docker Volumes"
    
    if ! command -v docker &> /dev/null || ! docker info &> /dev/null 2>&1; then
        print_warning "Docker not available, skipping Docker backup"
        return 0
    fi
    
    local docker_backup_dir="${BACKUP_DIR}/docker"
    
    # Get list of volumes
    volumes=$(docker volume ls --format '{{.Name}}' | grep -E '^frontier-llm-mac-stack_' || true)
    
    if [[ -z "$volumes" ]]; then
        print_warning "No Frontier LLM Stack Docker volumes found"
        return 0
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        print_status "[DRY RUN] Would backup Docker volumes:"
        echo "$volumes" | sed 's/^/  - /'
    else
        mkdir -p "$docker_backup_dir"
        
        for volume in $volumes; do
            print_status "Backing up volume: $volume"
            
            # Create temporary container to access volume
            docker run --rm \
                -v "$volume:/source:ro" \
                -v "$docker_backup_dir:/backup" \
                alpine tar czf "/backup/${volume}.tar.gz" -C /source .
        done
        
        print_status "Docker volumes backed up to: $docker_backup_dir"
    fi
}

# Backup configurations
backup_configurations() {
    print_header "Backing up Configurations"
    
    local config_backup_dir="${BACKUP_DIR}/configs"
    
    # List of configuration files and directories to backup
    config_items=(
        ~/.aider.conf.yml
        ~/.config/aider
        ~/.ollama
        ~/Library/LaunchAgents/com.ollama.server.plist
        ./config
        ./.env
        ./docker-compose.yml
        ./docker-compose.override.yml
    )
    
    if [[ "$DRY_RUN" == true ]]; then
        print_status "[DRY RUN] Would backup configurations:"
        for item in "${config_items[@]}"; do
            if [[ -e "$item" ]]; then
                echo "  - $item"
            fi
        done
    else
        mkdir -p "$config_backup_dir"
        
        # Create tar archive of configurations
        tar_file="${config_backup_dir}/configurations.tar"
        
        # Build tar command with existing files only
        tar_cmd="tar -cf $tar_file"
        for item in "${config_items[@]}"; do
            if [[ -e "$item" ]]; then
                tar_cmd="$tar_cmd \"$item\""
            fi
        done
        
        eval $tar_cmd 2>/dev/null || true
        
        # Compress based on selected method
        case "$COMPRESSION" in
            gzip)
                gzip "$tar_file"
                print_status "Configurations backed up to: ${tar_file}.gz"
                ;;
            bzip2)
                bzip2 "$tar_file"
                print_status "Configurations backed up to: ${tar_file}.bz2"
                ;;
            xz)
                xz "$tar_file"
                print_status "Configurations backed up to: ${tar_file}.xz"
                ;;
            none)
                print_status "Configurations backed up to: $tar_file"
                ;;
        esac
    fi
}

# Create backup metadata
create_backup_metadata() {
    if [[ "$DRY_RUN" == true ]]; then
        return 0
    fi
    
    print_header "Creating Backup Metadata"
    
    cat > "${BACKUP_DIR}/backup-metadata.json" << EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "hostname": "$(hostname)",
  "user": "$USER",
  "backup_version": "1.0",
  "components": {
    "ollama_version": "$(ollama --version 2>/dev/null || echo 'not installed')",
    "docker_version": "$(docker --version 2>/dev/null || echo 'not installed')",
    "os_version": "$(sw_vers -productVersion 2>/dev/null || uname -r)"
  },
  "compression": "$COMPRESSION",
  "backup_size": "$(du -sh "$BACKUP_DIR" 2>/dev/null | awk '{print $1}')"
}
EOF
    
    print_status "Metadata saved to: ${BACKUP_DIR}/backup-metadata.json"
}

# Cleanup old backups
cleanup_old_backups() {
    print_header "Cleaning Up Old Backups"
    
    if [[ ! -d "$BACKUP_ROOT" ]]; then
        return 0
    fi
    
    # Find backups older than retention period
    old_backups=$(find "$BACKUP_ROOT" -maxdepth 1 -type d -name "20*" -mtime +$RETENTION_DAYS 2>/dev/null || true)
    
    if [[ -z "$old_backups" ]]; then
        print_status "No old backups to clean up"
        return 0
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        print_status "[DRY RUN] Would delete these old backups:"
        echo "$old_backups"
    else
        echo "$old_backups" | while read -r backup; do
            print_status "Deleting old backup: $backup"
            rm -rf "$backup"
        done
    fi
}

# Restore function
restore_backup() {
    local backup_path=$1
    
    print_header "Restore from Backup"
    
    if [[ ! -d "$backup_path" ]]; then
        print_error "Backup directory not found: $backup_path"
        exit 1
    fi
    
    # Show backup info
    if [[ -f "$backup_path/backup-metadata.json" ]]; then
        print_status "Backup information:"
        jq '.' "$backup_path/backup-metadata.json" 2>/dev/null || cat "$backup_path/backup-metadata.json"
    fi
    
    print_warning "This will restore from backup: $backup_path"
    read -p "Are you sure you want to continue? (yes/no) " -r
    if [[ ! $REPLY =~ ^yes$ ]]; then
        print_status "Restore cancelled"
        exit 0
    fi
    
    # Restore models
    if [[ -d "$backup_path/ollama-models" ]]; then
        print_status "Restoring Ollama models..."
        rsync -av --progress "$backup_path/ollama-models/" ~/ollama-models/
    fi
    
    # Restore configurations
    if [[ -f "$backup_path/configs/configurations.tar.gz" ]]; then
        print_status "Restoring configurations..."
        tar -xzf "$backup_path/configs/configurations.tar.gz" -C /
    fi
    
    # Restore Docker volumes
    if [[ -d "$backup_path/docker" ]]; then
        print_status "Restoring Docker volumes..."
        for volume_backup in "$backup_path/docker"/*.tar.gz; do
            volume_name=$(basename "$volume_backup" .tar.gz)
            print_status "Restoring volume: $volume_name"
            
            # Create volume if it doesn't exist
            docker volume create "$volume_name" 2>/dev/null || true
            
            # Restore data
            docker run --rm \
                -v "$volume_name:/restore" \
                -v "$backup_path/docker:/backup:ro" \
                alpine tar xzf "/backup/$(basename "$volume_backup")" -C /restore
        done
    fi
    
    print_status "Restore complete!"
}

# Main backup process
main() {
    # Check for restore mode
    if [[ "${1:-}" == "restore" ]]; then
        if [[ -z "${2:-}" ]]; then
            print_error "Please specify backup directory to restore from"
            echo "Usage: $0 restore /path/to/backup/20240101_120000"
            exit 1
        fi
        restore_backup "$2"
        exit 0
    fi
    
    # Regular backup mode
    if ! check_backup_space; then
        exit 1
    fi
    
    if [[ "$DRY_RUN" == false ]]; then
        mkdir -p "$BACKUP_DIR"
        print_status "Backup directory: $BACKUP_DIR"
    fi
    
    # Perform backups
    backup_ollama_models
    backup_docker_volumes
    backup_configurations
    create_backup_metadata
    
    # Cleanup old backups
    cleanup_old_backups
    
    if [[ "$DRY_RUN" == false ]]; then
        # Calculate final backup size
        backup_size=$(du -sh "$BACKUP_DIR" 2>/dev/null | awk '{print $1}')
        
        print_header "Backup Complete!"
        print_status "Backup location: $BACKUP_DIR"
        print_status "Backup size: $backup_size"
        print_status "To restore from this backup, run:"
        echo "  $0 restore $BACKUP_DIR"
    else
        print_header "Dry Run Complete"
        print_status "No actual backup was created"
    fi
}

# Run main function
main "$@"