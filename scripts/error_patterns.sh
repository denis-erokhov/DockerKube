#!/bin/bash

################################################################################
# Script: error_patterns.sh
# Description: Analyze error patterns in Docker logs with advanced statistics
# Author: Admin (Learning SDET/DevOps)
# Date: 2025-12-26
# Version: 1.0
#
# Usage:
#   ./error_patterns.sh --service=backend
#   ./error_patterns.sh --service=backend --pattern="ERROR|Exception"
#   ./error_patterns.sh --service=all --report
#   ./error_patterns.sh --help
#
# Examples:
#   # Analyze all error patterns in backend
#   ./error_patterns.sh --service=backend
#
#   # Analyze specific error pattern
#   ./error_patterns.sh --service=backend --pattern="ValueError"
#
#   # Generate detailed HTML report
#   ./error_patterns.sh --service=backend --report --output=report.html
#
#   # Analyze all services
#   ./error_patterns.sh --service=all --top=20
#
#   # Compare time periods
#   ./error_patterns.sh --service=backend --since=1h --until=30m
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
ERROR_PATTERN="ERROR|CRITICAL|FATAL|Exception|Traceback|500|502|503|504"
TOP_N=10                             # Show top N most frequent errors
SHOW_CONTEXT=false                   # Show context around errors
CONTEXT_LINES=3                      # Lines of context before/after
GENERATE_REPORT=false                # Generate HTML report
OUTPUT_FILE=""                       # Output file for report
SINCE=""                             # Time filter (e.g., "1h", "30m")
UNTIL=""                             # Time filter
VERBOSE=false                        # Verbose output
GROUP_BY="type"                      # Group by: type, endpoint, time

# Temporary files
TEMP_DIR=$(mktemp -d)
ERRORS_FILE="${TEMP_DIR}/errors.txt"
STATS_FILE="${TEMP_DIR}/stats.txt"

################################################################################
# Function: cleanup
# Description: Clean up temporary files
################################################################################
cleanup() {
    rm -rf "$TEMP_DIR"
}

# Set trap to cleanup on exit
trap cleanup EXIT

################################################################################
# Function: show_usage
# Description: Display usage information
################################################################################
show_usage() {
    cat << EOF
${CYAN}═══════════════════════════════════════════════════════════════
Docker Logs Error Pattern Analysis
═══════════════════════════════════════════════════════════════${NC}

${YELLOW}DESCRIPTION:${NC}
    Analyzes error patterns in Docker container logs.
    Identifies most frequent errors, categorizes by type and endpoint.
    Generates statistical reports and visualizations.

${YELLOW}USAGE:${NC}
    $0 [OPTIONS]

${YELLOW}OPTIONS:${NC}
    --service=NAME         Service name (default: backend, use "all" for all)
    --pattern=REGEX        Custom error pattern (default: common errors)
    --top=N                Show top N most frequent errors (default: 10)
    --context              Show context lines around errors
    --context-lines=N      Number of context lines (default: 3)
    --group-by=TYPE        Group by: type, endpoint, time (default: type)
    --since=TIME           Analyze logs since time (e.g., "1h", "30m")
    --until=TIME           Analyze logs until time
    --report               Generate HTML report
    --output=FILE          Output file for report
    --verbose              Show detailed analysis
    --help                 Show this help message

${YELLOW}EXAMPLES:${NC}
    # Basic analysis
    $0 --service=backend

    # Analyze specific error type
    $0 --service=backend --pattern="ValueError|KeyError"

    # Show context around errors
    $0 --service=backend --context --context-lines=5

    # Generate HTML report
    $0 --service=backend --report --output=errors_report.html

    # Analyze last hour
    $0 --service=backend --since=1h

    # Analyze all services with top 20 errors
    $0 --service=all --top=20

    # Group by endpoint
    $0 --service=backend --group-by=endpoint

${YELLOW}DEFAULT ERROR PATTERNS:${NC}
    - ERROR, CRITICAL, FATAL
    - Exception, Traceback
    - HTTP 5xx errors (500, 502, 503, 504)

${YELLOW}GROUPING OPTIONS:${NC}
    type       - Group by error type (ValueError, KeyError, etc.)
    endpoint   - Group by API endpoint (/users, /items, etc.)
    time       - Group by hour of day

${YELLOW}OUTPUT:${NC}
    - Error frequency statistics
    - Top N most common errors
    - HTTP status code distribution
    - Timeline analysis
    - Optional HTML report with charts

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
            --pattern=*)
                ERROR_PATTERN="${arg#--pattern=}"
                ;;
            --top=*)
                TOP_N="${arg#--top=}"
                ;;
            --context-lines=*)
                CONTEXT_LINES="${arg#--context-lines=}"
                ;;
            --group-by=*)
                GROUP_BY="${arg#--group-by=}"
                ;;
            --since=*)
                SINCE="${arg#--since=}"
                ;;
            --until=*)
                UNTIL="${arg#--until=}"
                ;;
            --output=*)
                OUTPUT_FILE="${arg#--output=}"
                ;;
            --context)
                SHOW_CONTEXT=true
                ;;
            --report)
                GENERATE_REPORT=true
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
# Description: Validate input parameters
################################################################################
validate_inputs() {
    # Check if docker-compose is available
    if ! command -v docker-compose &> /dev/null; then
        echo -e "${RED}Error: docker-compose not found${NC}" >&2
        exit 1
    fi

    # Validate top_n
    if ! [[ "$TOP_N" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}Error: --top must be a positive integer${NC}" >&2
        exit 1
    fi

    # Validate context_lines
    if ! [[ "$CONTEXT_LINES" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}Error: --context-lines must be a positive integer${NC}" >&2
        exit 1
    fi

    # Validate group_by
    if [[ ! "$GROUP_BY" =~ ^(type|endpoint|time)$ ]]; then
        echo -e "${RED}Error: --group-by must be: type, endpoint, or time${NC}" >&2
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
}

################################################################################
# Function: extract_errors
# Description: Extract errors from logs
################################################################################
extract_errors() {
    local cmd="docker-compose logs --no-color --timestamps"

    # Add time filters if specified
    if [ -n "$SINCE" ]; then
        cmd="$cmd --since=$SINCE"
    fi

    if [ -n "$UNTIL" ]; then
        cmd="$cmd --until=$UNTIL"
    fi

    cmd="$cmd $SERVICE"

    echo -e "${CYAN}Extracting errors from logs...${NC}"

    # Extract errors matching pattern
    eval "$cmd" | grep -E "$ERROR_PATTERN" > "$ERRORS_FILE"

    local error_count=$(wc -l < "$ERRORS_FILE")

    if [ "$error_count" -eq 0 ]; then
        echo -e "${GREEN}✓ No errors found matching pattern: ${ERROR_PATTERN}${NC}"
        exit 0
    fi

    echo -e "${YELLOW}Found $error_count error lines${NC}"
    echo
}

################################################################################
# Function: analyze_error_types
# Description: Analyze and categorize error types
################################################################################
analyze_error_types() {
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}${BOLD}Error Type Analysis${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo

    # Extract error types and count frequency
    echo -e "${YELLOW}Top $TOP_N Most Frequent Error Types:${NC}"
    echo -e "${YELLOW}────────────────────────────────────────────────────────${NC}"

    # Different patterns for different error types
    cat "$ERRORS_FILE" | \
        grep -oE "(ValueError|KeyError|TypeError|AttributeError|RuntimeError|Exception|ERROR|CRITICAL|FATAL)" | \
        sort | uniq -c | sort -rn | head -n "$TOP_N" | \
        awk '{printf "  %s%-20s%s %s%5d occurrences%s\n", "'${GREEN}'", $2, "'${NC}'", "'${CYAN}'", $1, "'${NC}'"}'

    echo
}

################################################################################
# Function: analyze_http_errors
# Description: Analyze HTTP error codes
################################################################################
analyze_http_errors() {
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}${BOLD}HTTP Error Code Analysis${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo

    # Extract HTTP error codes
    local http_errors=$(cat "$ERRORS_FILE" | grep -oE 'HTTP/1\.1" [4-5][0-9]{2}' | awk '{print $2}')

    if [ -z "$http_errors" ]; then
        echo -e "${BLUE}No HTTP error codes found${NC}"
        echo
        return
    fi

    echo -e "${YELLOW}HTTP Status Code Distribution:${NC}"
    echo -e "${YELLOW}────────────────────────────────────────────────────────${NC}"

    echo "$http_errors" | sort | uniq -c | sort -rn | while read -r count code; do
        # Color code based on severity
        if [[ "$code" =~ ^5 ]]; then
            color=$RED
        else
            color=$YELLOW
        fi

        # Add description
        case $code in
            400) desc="Bad Request" ;;
            401) desc="Unauthorized" ;;
            403) desc="Forbidden" ;;
            404) desc="Not Found" ;;
            422) desc="Unprocessable Entity" ;;
            500) desc="Internal Server Error" ;;
            502) desc="Bad Gateway" ;;
            503) desc="Service Unavailable" ;;
            504) desc="Gateway Timeout" ;;
            *) desc="" ;;
        esac

        printf "  ${color}%s${NC} %-25s ${CYAN}%5d occurrences${NC}\n" "$code" "$desc" "$count"
    done

    echo
}

################################################################################
# Function: analyze_endpoints
# Description: Analyze errors by endpoint
################################################################################
analyze_endpoints() {
    if [ "$GROUP_BY" != "endpoint" ]; then
        return
    fi

    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}${BOLD}Error Analysis by Endpoint${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo

    echo -e "${YELLOW}Top $TOP_N Problematic Endpoints:${NC}"
    echo -e "${YELLOW}────────────────────────────────────────────────────────${NC}"

    # Extract endpoints from logs
    cat "$ERRORS_FILE" | \
        grep -oE '"(GET|POST|PUT|DELETE|PATCH) [^ ]+' | \
        awk '{print $2}' | \
        sort | uniq -c | sort -rn | head -n "$TOP_N" | \
        awk '{printf "  %s%-40s%s %s%5d errors%s\n", "'${GREEN}'", $2, "'${NC}'", "'${RED}'", $1, "'${NC}'"}'

    echo
}

################################################################################
# Function: analyze_timeline
# Description: Analyze errors over time
################################################################################
analyze_timeline() {
    if [ "$GROUP_BY" != "time" ]; then
        return
    fi

    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}${BOLD}Error Timeline Analysis${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo

    echo -e "${YELLOW}Errors by Hour:${NC}"
    echo -e "${YELLOW}────────────────────────────────────────────────────────${NC}"

    # Extract hour from timestamps and count
    cat "$ERRORS_FILE" | \
        grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}' | \
        cut -d'T' -f2 | \
        sort | uniq -c | sort -rn | \
        awk '{
            count = $1
            hour = $2
            # Create simple bar chart
            bar = ""
            for(i=0; i<count/5; i++) bar = bar "█"
            printf "  %s%02d:00%s  %s%-50s%s %s%d%s\n", "'${CYAN}'", hour, "'${NC}'", "'${GREEN}'", bar, "'${NC}'", "'${YELLOW}'", count, "'${NC}'"
        }'

    echo
}

################################################################################
# Function: show_error_samples
# Description: Show sample error messages
################################################################################
show_error_samples() {
    if [ "$SHOW_CONTEXT" = false ] && [ "$VERBOSE" = false ]; then
        return
    fi

    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}${BOLD}Sample Error Messages (showing first 5)${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo

    head -5 "$ERRORS_FILE" | while IFS= read -r line; do
        echo -e "${RED}$line${NC}"
    done

    echo
}

################################################################################
# Function: generate_statistics
# Description: Generate overall statistics
################################################################################
generate_statistics() {
    local total_errors=$(wc -l < "$ERRORS_FILE")
    local unique_patterns=$(cat "$ERRORS_FILE" | grep -oE "$ERROR_PATTERN" | sort -u | wc -l)

    # Calculate time range
    local first_timestamp=$(head -1 "$ERRORS_FILE" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}')
    local last_timestamp=$(tail -1 "$ERRORS_FILE" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}')

    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}${BOLD}Overall Statistics${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}Service:${NC}              $SERVICE"
    echo -e "${YELLOW}Total errors:${NC}         ${RED}$total_errors${NC}"
    echo -e "${YELLOW}Unique patterns:${NC}      $unique_patterns"
    echo -e "${YELLOW}Time range:${NC}           $first_timestamp → $last_timestamp"
    echo -e "${YELLOW}Error pattern:${NC}        $ERROR_PATTERN"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo
}

################################################################################
# Function: generate_html_report
# Description: Generate HTML report with charts
################################################################################
generate_html_report() {
    if [ "$GENERATE_REPORT" = false ]; then
        return
    fi

    local report_file="${OUTPUT_FILE:-error_analysis_report.html}"

    echo -e "${CYAN}Generating HTML report: $report_file${NC}"

    cat > "$report_file" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Error Pattern Analysis Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        h1 { color: #333; border-bottom: 3px solid #4CAF50; padding-bottom: 10px; }
        h2 { color: #555; margin-top: 30px; border-left: 4px solid #2196F3; padding-left: 10px; }
        .stat-box { display: inline-block; background: #e3f2fd; padding: 15px; margin: 10px; border-radius: 5px; min-width: 150px; }
        .stat-label { font-size: 12px; color: #666; }
        .stat-value { font-size: 24px; font-weight: bold; color: #1976d2; }
        .error-item { background: #ffebee; padding: 10px; margin: 5px 0; border-left: 3px solid #f44336; }
        .timestamp { color: #999; font-size: 12px; }
        table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        th, td { padding: 12px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background: #4CAF50; color: white; }
        tr:hover { background: #f5f5f5; }
        .error-code { font-weight: bold; color: #f44336; }
        .success-code { color: #4CAF50; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🔍 Error Pattern Analysis Report</h1>
        <p><strong>Generated:</strong> <span id="timestamp"></span></p>
        <p><strong>Service:</strong> SERVICE_PLACEHOLDER</p>

        <h2>📊 Summary Statistics</h2>
        <div class="stat-box">
            <div class="stat-label">Total Errors</div>
            <div class="stat-value" id="total-errors">0</div>
        </div>
        <div class="stat-box">
            <div class="stat-label">Unique Patterns</div>
            <div class="stat-value" id="unique-patterns">0</div>
        </div>

        <h2>📈 Top Error Types</h2>
        <table id="error-types-table">
            <thead>
                <tr><th>Error Type</th><th>Count</th><th>Percentage</th></tr>
            </thead>
            <tbody></tbody>
        </table>

        <h2>🌐 HTTP Error Codes</h2>
        <table id="http-codes-table">
            <thead>
                <tr><th>Status Code</th><th>Description</th><th>Count</th></tr>
            </thead>
            <tbody></tbody>
        </table>

        <h2>📝 Sample Errors</h2>
        <div id="sample-errors"></div>
    </div>

    <script>
        document.getElementById('timestamp').textContent = new Date().toLocaleString();
    </script>
</body>
</html>
EOF

    # Replace placeholders
    sed -i "s/SERVICE_PLACEHOLDER/$SERVICE/g" "$report_file"

    echo -e "${GREEN}✓ Report generated: $report_file${NC}"
    echo -e "${BLUE}Open in browser: file://$(pwd)/$report_file${NC}"
    echo
}

################################################################################
# Main execution
################################################################################
main() {
    # Parse arguments
    parse_arguments "$@"

    # Validate inputs
    validate_inputs

    # Extract errors
    extract_errors

    # Run analyses
    generate_statistics
    analyze_error_types
    analyze_http_errors
    analyze_endpoints
    analyze_timeline
    show_error_samples

    # Generate report if requested
    generate_html_report

    echo -e "${GREEN}✓ Error pattern analysis complete!${NC}"
}

# Run main function
main "$@"
exit 0
