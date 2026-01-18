#!/bin/bash

################################################################################
# Script: find_slow_requests.sh
# Description: Find slow HTTP requests in Docker container logs
# Author: Denis E. (Learning SDET/DevOps)
# Date: 2025-12-25
# Version: 1.0
#
# Usage:
#   ./find_slow_requests.sh --threshold=2.0 --service=backend
#   ./find_slow_requests.sh --threshold=5.0 --top=10
#   ./find_slow_requests.sh --help
#
# Examples:
#   # Find requests slower than 2 seconds
#   ./find_slow_requests.sh --threshold=2.0
#
#   # Find top 10 slowest requests
#   ./find_slow_requests.sh --top=10
#
#   # Analyze specific service
#   ./find_slow_requests.sh --service=backend --threshold=1.5
################################################################################

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default values
THRESHOLD=1.0  # seconds
SERVICE="backend"
TOP_N=20
OUTPUT_FILE=""

################################################################################
# Function: show_usage
# Description: Display usage information
################################################################################
show_usage() {
    cat << EOF
${CYAN}═══════════════════════════════════════════════════════════════
Find Slow HTTP Requests in Docker Logs
═══════════════════════════════════════════════════════════════${NC}

${YELLOW}USAGE:${NC}
    $0 [OPTIONS]

${YELLOW}OPTIONS:${NC}
    --threshold=N    Threshold in seconds (default: 1.0)
    --service=NAME   Service name (default: backend)
    --top=N          Show top N slowest requests (default: 20)
    --output=FILE    Save results to file
    --help           Show this help message

${YELLOW}EXAMPLES:${NC}
    # Find requests slower than 2 seconds
    $0 --threshold=2.0

    # Find top 10 slowest requests
    $0 --top=10

    # Save results to file
    $0 --threshold=1.5 --output=slow_requests.txt

    # Analyze specific service
    $0 --service=tests --threshold=5.0

${YELLOW}OUTPUT FORMAT:${NC}
    TIME_MS | HTTP_METHOD | ENDPOINT | STATUS_CODE | TIMESTAMP

${YELLOW}NOTES:${NC}
    - Parses Uvicorn access logs (FastAPI default format)
    - Threshold is in seconds (e.g., 1.5 = 1500ms)
    - Results are sorted by response time (slowest first)

EOF
}

################################################################################
# Function: parse_arguments
# Description: Parse command-line arguments
################################################################################
parse_arguments() {
    for arg in "$@"; do
        case $arg in
            --threshold=*)
                THRESHOLD="${arg#--threshold=}"
                ;;
            --service=*)
                SERVICE="${arg#--service=}"
                ;;
            --top=*)
                TOP_N="${arg#--top=}"
                ;;
            --output=*)
                OUTPUT_FILE="${arg#--output=}"
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

    # Check if service exists
    if ! docker-compose ps "$SERVICE" &> /dev/null; then
        echo -e "${RED}Error: Service '$SERVICE' not found${NC}" >&2
        echo "Available services:"
        docker-compose ps --services
        exit 1
    fi

    # Validate threshold is a number
    if ! [[ "$THRESHOLD" =~ ^[0-9]+\.?[0-9]*$ ]]; then
        echo -e "${RED}Error: Threshold must be a number${NC}" >&2
        exit 1
    fi

    # Validate top_n is a number
    if ! [[ "$TOP_N" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}Error: --top must be a positive integer${NC}" >&2
        exit 1
    fi
}

################################################################################
# Function: find_slow_requests
# Description: Main function to find slow requests
################################################################################
find_slow_requests() {
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}Searching for slow requests (> ${THRESHOLD}s) in '$SERVICE'${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo

    # Convert threshold to milliseconds for comparison
    THRESHOLD_MS=$(echo "$THRESHOLD * 1000" | bc | cut -d'.' -f1)

    # Extract slow requests from logs
    # Uvicorn log format: "GET /users HTTP/1.1" 200 OK - completed in 125ms
    local temp_file=$(mktemp)

    docker-compose logs --no-color "$SERVICE" | \
        grep -E "completed in [0-9]+ms" | \
        while IFS= read -r line; do
            # Extract response time in ms
            time_ms=$(echo "$line" | grep -oE "completed in [0-9]+ms" | grep -oE "[0-9]+")

            # Compare with threshold
            if [ "$time_ms" -ge "$THRESHOLD_MS" ]; then
                # Extract HTTP method, endpoint, status code
                method=$(echo "$line" | grep -oE '"(GET|POST|PUT|DELETE|PATCH)' | tr -d '"')
                endpoint=$(echo "$line" | grep -oE '"[A-Z]+ [^ ]+' | cut -d' ' -f2-)
                status=$(echo "$line" | grep -oE 'HTTP/1\.1" [0-9]{3}' | awk '{print $2}')
                timestamp=$(echo "$line" | grep -oE '^[^ ]+' | head -1)

                # Print in formatted way
                printf "%6dms | %-6s | %-30s | %3s | %s\n" \
                    "$time_ms" "$method" "$endpoint" "$status" "$timestamp"
            fi
        done | sort -rn | head -n "$TOP_N" > "$temp_file"

    # Count results
    local count=$(wc -l < "$temp_file")

    if [ "$count" -eq 0 ]; then
        echo -e "${GREEN}✓ No slow requests found (all requests < ${THRESHOLD}s)${NC}"
        rm "$temp_file"
        return 0
    fi

    # Display header
    echo -e "${YELLOW}TIME   | METHOD | ENDPOINT                       | STATUS | TIMESTAMP${NC}"
    echo -e "${YELLOW}─────────────────────────────────────────────────────────────────────────────${NC}"

    # Display results
    cat "$temp_file"

    echo
    echo -e "${CYAN}─────────────────────────────────────────────────────────────────────────────${NC}"
    echo -e "${GREEN}Found $count slow requests (showing top $TOP_N)${NC}"
    echo -e "${CYAN}─────────────────────────────────────────────────────────────────────────────${NC}"

    # Save to file if requested
    if [ -n "$OUTPUT_FILE" ]; then
        cp "$temp_file" "$OUTPUT_FILE"
        echo -e "${GREEN}✓ Results saved to: $OUTPUT_FILE${NC}"
    fi

    rm "$temp_file"
}

################################################################################
# Function: show_statistics
# Description: Show statistics about response times
################################################################################
show_statistics() {
    echo
    echo -e "${CYAN}Response Time Statistics:${NC}"
    echo -e "${CYAN}─────────────────────────────────────────────────────────────────────────────${NC}"

    # Extract all response times
    local times=$(docker-compose logs --no-color "$SERVICE" | \
        grep -oE "completed in [0-9]+ms" | \
        grep -oE "[0-9]+" | \
        sort -n)

    if [ -z "$times" ]; then
        echo -e "${YELLOW}No timing data found in logs${NC}"
        return
    fi

    local count=$(echo "$times" | wc -l)
    local min=$(echo "$times" | head -1)
    local max=$(echo "$times" | tail -1)
    local avg=$(echo "$times" | awk '{sum+=$1} END {print sum/NR}' | cut -d'.' -f1)

    # Calculate percentiles
    local p50_index=$(echo "$count * 0.50" | bc | cut -d'.' -f1)
    local p95_index=$(echo "$count * 0.95" | bc | cut -d'.' -f1)
    local p99_index=$(echo "$count * 0.99" | bc | cut -d'.' -f1)

    local p50=$(echo "$times" | sed -n "${p50_index}p")
    local p95=$(echo "$times" | sed -n "${p95_index}p")
    local p99=$(echo "$times" | sed -n "${p99_index}p")

    echo -e "Total requests:  ${GREEN}$count${NC}"
    echo -e "Min time:        ${GREEN}${min}ms${NC}"
    echo -e "Max time:        ${RED}${max}ms${NC}"
    echo -e "Average time:    ${YELLOW}${avg}ms${NC}"
    echo -e "p50 (median):    ${CYAN}${p50}ms${NC}"
    echo -e "p95:             ${CYAN}${p95}ms${NC}"
    echo -e "p99:             ${CYAN}${p99}ms${NC}"
}

################################################################################
# Main execution
################################################################################
main() {
    # Parse arguments
    parse_arguments "$@"

    # Validate inputs
    validate_inputs

    # Find slow requests
    find_slow_requests

    # Show statistics
    show_statistics

    echo
    echo -e "${GREEN}✓ Analysis complete!${NC}"
}

# Run main function
main "$@"
exit 0
