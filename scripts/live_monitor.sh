#!/bin/bash

################################################################################
# Script: live_monitor.sh
# Description: Real-time monitoring of Docker logs with alerts
# Author: Admin (Learning SDET/DevOps)
# Date: 2025-12-26
# Version: 1.0
#
# Usage:
#   ./live_monitor.sh --service=backend
#   ./live_monitor.sh --service=backend --alert-on=ERROR
#   ./live_monitor.sh --service=all --notify
#   ./live_monitor.sh --help
#
# Examples:
#   # Monitor backend logs in real-time
#   ./live_monitor.sh --service=backend
#
#   # Monitor with alerts on ERROR keyword
#   ./live_monitor.sh --service=backend --alert-on=ERROR
#
#   # Monitor with multiple alert patterns
#   ./live_monitor.sh --service=backend --alert-on="ERROR|CRITICAL|500"
#
#   # Monitor all services
#   ./live_monitor.sh --service=all --alert-on=ERROR
#
#   # Save alerts to file
#   ./live_monitor.sh --service=backend --alert-on=ERROR --save-alerts
################################################################################

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Default values
SERVICE="backend"
ALERT_PATTERN=""                     # Pattern to alert on (e.g., "ERROR|500")
TAIL_LINES=50                        # Number of initial lines to show
SAVE_ALERTS=false                    # Save alerts to file
ALERTS_FILE="logs/alerts/alerts.log" # File to save alerts
SHOW_TIMESTAMPS=true                 # Show timestamps in output
HIGHLIGHT_PATTERN=""                 # Pattern to highlight (different from alerts)
FOLLOW_MODE=true                     # Follow logs in real-time
SOUND_ALERT=false                    # Play sound on alert (requires 'beep' or similar)

# Statistics counters
TOTAL_LINES=0
ALERT_COUNT=0
ERROR_COUNT=0
WARNING_COUNT=0
START_TIME=$(date +%s)

################################################################################
# Function: show_usage
# Description: Display usage information
################################################################################
show_usage() {
    cat << EOF
${CYAN}═══════════════════════════════════════════════════════════════
Docker Logs Live Monitor with Alerts
═══════════════════════════════════════════════════════════════${NC}

${YELLOW}DESCRIPTION:${NC}
    Monitor Docker container logs in real-time with customizable alerts.
    Highlights errors, warnings, and custom patterns.
    Keeps statistics and can save alerts to file.

${YELLOW}USAGE:${NC}
    $0 [OPTIONS]

${YELLOW}OPTIONS:${NC}
    --service=NAME         Service name (default: backend, use "all" for all)
    --alert-on=PATTERN     Trigger alert on pattern (regex, e.g., "ERROR|500")
    --highlight=PATTERN    Highlight pattern (regex, without alerting)
    --tail=N               Show last N lines initially (default: 50)
    --save-alerts          Save alerts to file (${ALERTS_FILE})
    --alerts-file=PATH     Custom alerts file path
    --no-timestamps        Hide timestamps in output
    --no-follow            Show logs and exit (don't follow)
    --sound                Play sound on alert (requires system beep)
    --help                 Show this help message

${YELLOW}EXAMPLES:${NC}
    # Basic monitoring
    $0 --service=backend

    # Alert on errors
    $0 --service=backend --alert-on=ERROR

    # Alert on HTTP 5xx errors
    $0 --service=backend --alert-on="HTTP/1\.1\" 5[0-9]{2}"

    # Multiple patterns
    $0 --service=backend --alert-on="ERROR|CRITICAL|Exception"

    # Save alerts to custom file
    $0 --service=backend --alert-on=ERROR --save-alerts --alerts-file=critical.log

    # Monitor all services
    $0 --service=all --alert-on="ERROR|500"

${YELLOW}KEYBOARD SHORTCUTS:${NC}
    Ctrl+C             Stop monitoring and show statistics
    Ctrl+Z             Pause (resume with 'fg')

${YELLOW}COLOR CODING:${NC}
    ${RED}RED${NC}              ERROR, CRITICAL, 5xx codes
    ${YELLOW}YELLOW${NC}           WARNING, 4xx codes
    ${GREEN}GREEN${NC}            SUCCESS, 2xx codes
    ${CYAN}CYAN${NC}             INFO, timestamps
    ${MAGENTA}MAGENTA${NC}          Custom alert pattern

${YELLOW}ALERT FILE FORMAT:${NC}
    [YYYY-MM-DD HH:MM:SS] [SERVICE] LOG_LINE

${YELLOW}NOTES:${NC}
    - Press Ctrl+C to stop and see statistics
    - Alerts are both displayed and optionally saved to file
    - Pattern matching uses grep -E (extended regex)

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
            --alert-on=*)
                ALERT_PATTERN="${arg#--alert-on=}"
                ;;
            --highlight=*)
                HIGHLIGHT_PATTERN="${arg#--highlight=}"
                ;;
            --tail=*)
                TAIL_LINES="${arg#--tail=}"
                ;;
            --alerts-file=*)
                ALERTS_FILE="${arg#--alerts-file=}"
                ;;
            --save-alerts)
                SAVE_ALERTS=true
                ;;
            --no-timestamps)
                SHOW_TIMESTAMPS=false
                ;;
            --no-follow)
                FOLLOW_MODE=false
                ;;
            --sound)
                SOUND_ALERT=true
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
# Description: Validate input parameters
################################################################################
validate_inputs() {
    # Check if docker-compose is available
    if ! command -v docker-compose &> /dev/null; then
        echo -e "${RED}Error: docker-compose not found${NC}" >&2
        exit 1
    fi

    # Validate tail lines
    if ! [[ "$TAIL_LINES" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}Error: --tail must be a positive integer${NC}" >&2
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

    # Create alerts file directory if needed
    if [ "$SAVE_ALERTS" = true ]; then
        mkdir -p "$(dirname "$ALERTS_FILE")"
    fi
}

################################################################################
# Function: colorize_line
# Description: Add colors to log line based on content
# Arguments:
#   $1 - Log line
################################################################################
colorize_line() {
    local line="$1"

    # Check for different log levels and HTTP codes
    if echo "$line" | grep -qE "(ERROR|CRITICAL|FATAL|Exception|Traceback)"; then
        echo -e "${RED}${line}${NC}"
        ((ERROR_COUNT++))
    elif echo "$line" | grep -qE "(WARNING|WARN)"; then
        echo -e "${YELLOW}${line}${NC}"
        ((WARNING_COUNT++))
    elif echo "$line" | grep -qE 'HTTP/1\.1" 5[0-9]{2}'; then
        echo -e "${RED}${line}${NC}"
        ((ERROR_COUNT++))
    elif echo "$line" | grep -qE 'HTTP/1\.1" 4[0-9]{2}'; then
        echo -e "${YELLOW}${line}${NC}"
        ((WARNING_COUNT++))
    elif echo "$line" | grep -qE 'HTTP/1\.1" 2[0-9]{2}'; then
        echo -e "${GREEN}${line}${NC}"
    elif echo "$line" | grep -qE "(INFO|DEBUG)"; then
        echo -e "${CYAN}${line}${NC}"
    else
        echo "$line"
    fi
}

################################################################################
# Function: check_alert
# Description: Check if line matches alert pattern
# Arguments:
#   $1 - Log line
# Returns:
#   0 if matches, 1 if not
################################################################################
check_alert() {
    local line="$1"

    if [ -z "$ALERT_PATTERN" ]; then
        return 1
    fi

    if echo "$line" | grep -qE "$ALERT_PATTERN"; then
        return 0
    fi

    return 1
}

################################################################################
# Function: trigger_alert
# Description: Trigger alert for matching line
# Arguments:
#   $1 - Log line
################################################################################
trigger_alert() {
    local line="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    ((ALERT_COUNT++))

    # Print alert with special formatting
    echo -e "${BOLD}${MAGENTA}╔═════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${MAGENTA}║ ALERT #${ALERT_COUNT} - Pattern matched: ${ALERT_PATTERN}${NC}"
    echo -e "${BOLD}${MAGENTA}╚═════════════════════════════════════════════════════════════╝${NC}"
    colorize_line "$line"
    echo

    # Save to file if enabled
    if [ "$SAVE_ALERTS" = true ]; then
        echo "[$timestamp] [$SERVICE] $line" >> "$ALERTS_FILE"
    fi

    # Sound alert if enabled
    if [ "$SOUND_ALERT" = true ]; then
        # Try different methods to make a beep sound
        ( speaker-test -t sine -f 1000 -l 1 >/dev/null 2>&1 & ) || \
        ( echo -e '\a' ) || \
        true  # Don't fail if beep doesn't work
    fi
}

################################################################################
# Function: show_header
# Description: Display monitoring header
################################################################################
show_header() {
    clear
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}${BOLD}Docker Logs Live Monitor${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}Service:${NC}       $SERVICE"
    if [ -n "$ALERT_PATTERN" ]; then
        echo -e "${YELLOW}Alert on:${NC}      $ALERT_PATTERN"
    fi
    if [ "$SAVE_ALERTS" = true ]; then
        echo -e "${YELLOW}Alerts file:${NC}   $ALERTS_FILE"
    fi
    echo -e "${YELLOW}Started at:${NC}    $(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}Press Ctrl+C to stop and show statistics${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo
}

################################################################################
# Function: show_statistics
# Description: Display monitoring statistics (called on Ctrl+C)
################################################################################
show_statistics() {
    local end_time=$(date +%s)
    local duration=$((end_time - START_TIME))
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))

    echo
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}${BOLD}Monitoring Statistics${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}Service:${NC}           $SERVICE"
    echo -e "${YELLOW}Duration:${NC}          ${minutes}m ${seconds}s"
    echo -e "${YELLOW}Total lines:${NC}       ${TOTAL_LINES}"
    echo -e "${YELLOW}Errors:${NC}            ${RED}${ERROR_COUNT}${NC}"
    echo -e "${YELLOW}Warnings:${NC}          ${YELLOW}${WARNING_COUNT}${NC}"

    if [ -n "$ALERT_PATTERN" ]; then
        echo -e "${YELLOW}Alerts triggered:${NC}  ${MAGENTA}${ALERT_COUNT}${NC}"
    fi

    if [ "$SAVE_ALERTS" = true ] && [ -f "$ALERTS_FILE" ]; then
        local alert_file_lines=$(wc -l < "$ALERTS_FILE")
        echo -e "${YELLOW}Alerts saved:${NC}      ${alert_file_lines} (${ALERTS_FILE})"
    fi

    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}Monitoring stopped${NC}"
    echo
}

################################################################################
# Function: monitor_logs
# Description: Main monitoring function
################################################################################
monitor_logs() {
    # Setup trap to show statistics on exit
    trap show_statistics EXIT INT TERM

    # Show header
    show_header

    # Build docker-compose logs command
    local cmd="docker-compose logs --no-color"

    if [ "$SHOW_TIMESTAMPS" = true ]; then
        cmd="$cmd --timestamps"
    fi

    if [ "$FOLLOW_MODE" = true ]; then
        cmd="$cmd -f"
    fi

    cmd="$cmd --tail=$TAIL_LINES $SERVICE"

    # Monitor logs
    eval "$cmd" | while IFS= read -r line; do
        ((TOTAL_LINES++))

        # Check for alert
        if check_alert "$line"; then
            trigger_alert "$line"
        else
            # Normal colorized output
            colorize_line "$line"
        fi
    done
}

################################################################################
# Main execution
################################################################################
main() {
    # Parse arguments
    parse_arguments "$@"

    # Validate inputs
    validate_inputs

    # Start monitoring
    monitor_logs
}

# Run main function
main "$@"
exit 0
