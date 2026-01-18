#!/bin/bash

################################################################################
# Script: logs_rotation.sh
# Description: Automatic log rotation for Docker services with archiving
# Author: Admin (Learning SDET/DevOps)
# Date: 2025-12-26
# Version: 1.0
#
# Usage:
#   ./logs_rotation.sh --service=backend --max-files=5
#   ./logs_rotation.sh --service=all --compress
#   ./logs_rotation.sh --help
#
# Examples:
#   # Rotate backend logs, keep last 5 files
#   ./logs_rotation.sh --service=backend --max-files=5
#
#   # Rotate all services with compression
#   ./logs_rotation.sh --service=all --compress
#
#   # Custom rotation directory
#   ./logs_rotation.sh --service=backend --dir=logs/archive
#
#   # Dry-run mode (preview without actual rotation)
#   ./logs_rotation.sh --service=backend --dry-run
################################################################################

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
SERVICE="backend"
MAX_FILES=7                          # Keep last 7 rotated files
ROTATION_DIR="logs/rotated"          # Directory for rotated logs
COMPRESS=false                       # Compress rotated logs
DRY_RUN=false                        # Preview mode
VERBOSE=false                        # Verbose output
LINES=""                             # Number of lines to save (empty = all)

################################################################################
# Function: show_usage
# Description: Display usage information
################################################################################
show_usage() {
    cat << EOF
${CYAN}═══════════════════════════════════════════════════════════════
Docker Logs Rotation Script
═══════════════════════════════════════════════════════════════${NC}

${YELLOW}DESCRIPTION:${NC}
    Automatically rotates Docker container logs to prevent disk space issues.
    Saves logs with timestamp, optionally compresses, and removes old files.

${YELLOW}USAGE:${NC}
    $0 [OPTIONS]

${YELLOW}OPTIONS:${NC}
    --service=NAME      Service name from docker-compose.yml (default: backend)
                        Use "all" to rotate all services
    --max-files=N       Keep last N rotated files (default: 7)
    --dir=PATH          Rotation directory (default: logs/rotated)
    --compress          Compress rotated logs with gzip
    --lines=N           Save only last N lines (empty = all lines)
    --dry-run           Preview actions without executing
    --verbose           Show detailed output
    --help              Show this help message

${YELLOW}EXAMPLES:${NC}
    # Basic rotation (save all backend logs)
    $0 --service=backend

    # Rotate with compression, keep last 5 files
    $0 --service=backend --compress --max-files=5

    # Rotate only last 1000 lines
    $0 --service=backend --lines=1000

    # Rotate all services
    $0 --service=all --compress

    # Preview rotation without executing
    $0 --service=backend --dry-run

${YELLOW}OUTPUT FILES:${NC}
    Format: <service>_<YYYYMMDD>_<HHMMSS>.log[.gz]
    Example: backend_20251226_143045.log.gz

${YELLOW}AUTOMATION:${NC}
    To run automatically via cron (daily at 2 AM):
    0 2 * * * cd /path/to/DockerKube && ./scripts/logs_rotation.sh --service=all --compress

${YELLOW}NOTES:${NC}
    - Rotation does NOT clear Docker container logs (use 'docker-compose down' for that)
    - Only saves snapshots of current logs to files
    - Old rotated files are automatically deleted based on --max-files

EOF
}

################################################################################
# Function: parse_arguments
# Description: Parse command-line arguments
################################################################################
parse_arguments() {
    for arg in "$@"; do
        case $arg in
            --service=*)
                SERVICE="${arg#--service=}"
                ;;
            --max-files=*)
                MAX_FILES="${arg#--max-files=}"
                ;;
            --dir=*)
                ROTATION_DIR="${arg#--dir=}"
                ;;
            --lines=*)
                LINES="${arg#--lines=}"
                ;;
            --compress)
                COMPRESS=true
                ;;
            --dry-run)
                DRY_RUN=true
                ;;
            --verbose)
                VERBOSE=true
                ;;
            --help)
                show_usage
                exit 0
                ;;
            *)
                echo -e "${RED}Error: Unknown option: $arg${NC}" >&2
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
}

################################################################################
# Function: validate_inputs
# Description: Validate input parameters and dependencies
################################################################################
validate_inputs() {
    # Check if docker-compose is available
    if ! command -v docker-compose &> /dev/null; then
        echo -e "${RED}Error: docker-compose not found${NC}" >&2
        exit 1
    fi

    # Validate max-files is a positive number
    if ! [[ "$MAX_FILES" =~ ^[0-9]+$ ]] || [ "$MAX_FILES" -lt 1 ]; then
        echo -e "${RED}Error: --max-files must be a positive integer${NC}" >&2
        exit 1
    fi

    # Validate lines if specified
    if [ -n "$LINES" ] && ! [[ "$LINES" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}Error: --lines must be a positive integer${NC}" >&2
        exit 1
    fi

    # Check if service exists (skip if "all")
    if [ "$SERVICE" != "all" ]; then
        if ! docker-compose ps "$SERVICE" &> /dev/null; then
            echo -e "${RED}Error: Service '$SERVICE' not found${NC}" >&2
            echo "Available services:"
            docker-compose ps --services
            exit 1
        fi
    fi

    # Check if gzip is available when compress is enabled
    if [ "$COMPRESS" = true ] && ! command -v gzip &> /dev/null; then
        echo -e "${YELLOW}Warning: gzip not found, compression disabled${NC}" >&2
        COMPRESS=false
    fi
}

################################################################################
# Function: rotate_service_logs
# Description: Rotate logs for a single service
# Arguments:
#   $1 - Service name
################################################################################
rotate_service_logs() {
    local service=$1
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local filename="${service}_${timestamp}.log"
    local filepath="${ROTATION_DIR}/${filename}"

    echo -e "${CYAN}Rotating logs for service: ${YELLOW}${service}${NC}"

    # Get logs from container
    if [ -n "$LINES" ]; then
        if [ "$VERBOSE" = true ]; then
            echo -e "${BLUE}  → Extracting last $LINES lines...${NC}"
        fi
        local log_content=$(docker-compose logs --no-color --timestamps --tail="$LINES" "$service" 2>&1)
    else
        if [ "$VERBOSE" = true ]; then
            echo -e "${BLUE}  → Extracting all logs...${NC}"
        fi
        local log_content=$(docker-compose logs --no-color --timestamps "$service" 2>&1)
    fi

    # Check if logs are empty
    if [ -z "$log_content" ]; then
        echo -e "${YELLOW}  ⚠ No logs found for service '$service'${NC}"
        return 1
    fi

    local line_count=$(echo "$log_content" | wc -l)
    local size=$(echo "$log_content" | wc -c)
    local size_kb=$((size / 1024))

    if [ "$DRY_RUN" = true ]; then
        echo -e "${BLUE}  [DRY-RUN] Would save: $filepath${NC}"
        echo -e "${BLUE}  [DRY-RUN] Lines: $line_count, Size: ${size_kb}KB${NC}"
    else
        # Create directory if doesn't exist
        mkdir -p "$ROTATION_DIR"

        # Save logs to file
        echo "$log_content" > "$filepath"
        echo -e "${GREEN}  ✓ Saved: $filepath (${line_count} lines, ${size_kb}KB)${NC}"

        # Compress if enabled
        if [ "$COMPRESS" = true ]; then
            if [ "$VERBOSE" = true ]; then
                echo -e "${BLUE}  → Compressing...${NC}"
            fi
            gzip "$filepath"
            local compressed_size=$(stat -f%z "${filepath}.gz" 2>/dev/null || stat -c%s "${filepath}.gz" 2>/dev/null)
            local compressed_kb=$((compressed_size / 1024))
            local ratio=$((100 - (compressed_size * 100 / size)))
            echo -e "${GREEN}  ✓ Compressed: ${filepath}.gz (${compressed_kb}KB, saved ${ratio}%)${NC}"
        fi
    fi

    return 0
}

################################################################################
# Function: cleanup_old_files
# Description: Remove old rotated log files
# Arguments:
#   $1 - Service name
################################################################################
cleanup_old_files() {
    local service=$1
    local pattern="${service}_*.log"

    if [ "$COMPRESS" = true ]; then
        pattern="${service}_*.log.gz"
    fi

    # Count existing files
    local file_count=$(find "$ROTATION_DIR" -name "$pattern" 2>/dev/null | wc -l)

    if [ "$file_count" -le "$MAX_FILES" ]; then
        if [ "$VERBOSE" = true ]; then
            echo -e "${BLUE}  → Current files: $file_count (max: $MAX_FILES) - no cleanup needed${NC}"
        fi
        return 0
    fi

    # Calculate how many files to delete
    local delete_count=$((file_count - MAX_FILES))

    echo -e "${YELLOW}  Cleaning up old files (keeping last $MAX_FILES)...${NC}"

    if [ "$DRY_RUN" = true ]; then
        echo -e "${BLUE}  [DRY-RUN] Would delete $delete_count old files${NC}"
        find "$ROTATION_DIR" -name "$pattern" -type f | sort | head -n "$delete_count" | while read -r file; do
            echo -e "${BLUE}  [DRY-RUN] Would delete: $file${NC}"
        done
    else
        local deleted=0
        find "$ROTATION_DIR" -name "$pattern" -type f | sort | head -n "$delete_count" | while read -r file; do
            if [ "$VERBOSE" = true ]; then
                echo -e "${RED}  ✗ Deleting: $file${NC}"
            fi
            rm -f "$file"
            ((deleted++))
        done
        echo -e "${GREEN}  ✓ Deleted $delete_count old files${NC}"
    fi
}

################################################################################
# Function: rotate_all_services
# Description: Rotate logs for all services in docker-compose
################################################################################
rotate_all_services() {
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}Rotating logs for ALL services${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo

    # Get list of all services
    local services=$(docker-compose ps --services)
    local total=0
    local success=0
    local failed=0

    for svc in $services; do
        ((total++))
        echo -e "${CYAN}[$total] Service: $svc${NC}"

        if rotate_service_logs "$svc"; then
            cleanup_old_files "$svc"
            ((success++))
        else
            ((failed++))
        fi
        echo
    done

    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}Rotation complete: $success successful, $failed failed (total: $total)${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
}

################################################################################
# Function: show_rotation_summary
# Description: Display summary of rotated files
################################################################################
show_rotation_summary() {
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}This was a DRY-RUN. No files were actually created or deleted.${NC}"
        return
    fi

    if [ ! -d "$ROTATION_DIR" ]; then
        return
    fi

    echo
    echo -e "${CYAN}Rotation Directory: $ROTATION_DIR${NC}"

    # Calculate total size
    local total_size=$(du -sh "$ROTATION_DIR" 2>/dev/null | cut -f1)
    local file_count=$(find "$ROTATION_DIR" -type f | wc -l)

    echo -e "${CYAN}Total files: ${YELLOW}$file_count${NC}"
    echo -e "${CYAN}Total size: ${YELLOW}$total_size${NC}"

    if [ "$VERBOSE" = true ] && [ "$file_count" -gt 0 ]; then
        echo
        echo -e "${CYAN}Recent files:${NC}"
        find "$ROTATION_DIR" -type f | sort -r | head -5 | while read -r file; do
            local size=$(ls -lh "$file" | awk '{print $5}')
            local name=$(basename "$file")
            echo -e "  ${GREEN}$name${NC} ($size)"
        done
    fi
}

################################################################################
# Main execution
################################################################################
main() {
    # Parse arguments
    parse_arguments "$@"

    # Validate inputs
    validate_inputs

    # Show dry-run notice
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
        echo -e "${YELLOW}DRY-RUN MODE - No files will be created or deleted${NC}"
        echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
        echo
    fi

    # Rotate logs
    if [ "$SERVICE" = "all" ]; then
        rotate_all_services
    else
        echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
        echo -e "${CYAN}Docker Logs Rotation${NC}"
        echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
        echo

        rotate_service_logs "$SERVICE"
        cleanup_old_files "$SERVICE"
    fi

    # Show summary
    show_rotation_summary

    echo
    if [ "$DRY_RUN" = false ]; then
        echo -e "${GREEN}✓ Log rotation complete!${NC}"
    fi
}

# Run main function
main "$@"
exit 0
