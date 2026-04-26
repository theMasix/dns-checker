#!/bin/bash

################################################################################
# DNS Benchmark Script
# Tests multiple domains against multiple DNS servers and generates a report
################################################################################

# Configuration
TIMEOUT=2
ITERATIONS=2
OUTPUT_FILE="dns_benchmark_report_$(date +%Y%m%d_%H%M%S).txt"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

################################################################################
# Usage function
################################################################################
usage() {
    echo "Usage: $0 -d <domains_file> -s <dns_servers_file> [options]"
    echo ""
    echo "Options:"
    echo "  -d, --domains FILE      File containing domains (one per line)"
    echo "  -s, --servers FILE      File containing DNS servers (one per line)"
    echo "  -t, --timeout SECONDS   Query timeout (default: 5)"
    echo "  -i, --iterations NUM    Number of test iterations per domain (default: 3)"
    echo "  -o, --output FILE       Output report file"
    echo "  -h, --help              Show this help message"
    echo ""
    echo "Example:"
    echo "  $0 -d domains.txt -s dns_servers.txt"
    exit 1
}

################################################################################
# Parse command line arguments
################################################################################
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--domains)
            DOMAINS_FILE="$2"
            shift 2
            ;;
        -s|--servers)
            DNS_FILE="$2"
            shift 2
            ;;
        -t|--timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        -i|--iterations)
            ITERATIONS="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            usage
            ;;
    esac
done

################################################################################
# Validate input files
################################################################################
if [[ -z "$DOMAINS_FILE" ]] || [[ -z "$DNS_FILE" ]]; then
    echo -e "${RED}Error: Both domains and DNS servers files are required${NC}"
    usage
fi

if [[ ! -f "$DOMAINS_FILE" ]]; then
    echo -e "${RED}Error: Domains file not found: $DOMAINS_FILE${NC}"
    exit 1
fi

if [[ ! -f "$DNS_FILE" ]]; then
    echo -e "${RED}Error: DNS servers file not found: $DNS_FILE${NC}"
    exit 1
fi

################################################################################
# Read files into arrays
################################################################################
DOMAINS=()
while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    line="${line#[0-9]*[[:space:]]}"  # strip leading index like "1\t"
    DOMAINS+=("$line")
done < "$DOMAINS_FILE"

DNS_SERVERS=()
while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    line="${line#[0-9]*[[:space:]]}"  # strip leading index like "1\t"
    DNS_SERVERS+=("$line")
done < "$DNS_FILE"

################################################################################
# Helper Functions
################################################################################

# Get current timestamp
timestamp() {
    date "+%Y-%m-%d %H:%M:%S"
}

# Resolve domain using dig (returns time in ms or "FAIL")
resolve_with_dig() {
    local domain=$1
    local dns=$2
    
    local result=$(dig +short +time="$TIMEOUT" +tries=1 "@$dns" "$domain" A 2>/dev/null)
    if [[ -n "$result" ]]; then
        echo "$result"
        return 0
    fi
    return 1
}

# Get query time using dig
get_query_time() {
    local domain=$1
    local dns=$2
    
    # Use dig with +stats to get query time
    local dig_output=$(dig +time="$TIMEOUT" +tries=1 "@$dns" "$domain" A 2>&1)
    
    # Check if query was successful
    if echo "$dig_output" | grep -qi "timed out\|connection refused\|no servers could be reached\|SERVFAIL"; then
        echo "FAIL"
        return 1
    fi
    
    # Extract query time from dig stats
    local query_time=$(echo "$dig_output" | grep "Query time:" | awk '{print $4}')
    
    if [[ -n "$query_time" ]]; then
        echo "$query_time"
        return 0
    fi
    
    echo "FAIL"
    return 1
}

# Get detailed query stats
get_query_stats() {
    local domain=$1
    local dns=$2
    
    local dig_output=$(dig +time="$TIMEOUT" +tries=1 "@$dns" "$domain" A +stats 2>&1)
    
    # Check for errors
    if echo "$dig_output" | grep -qi "timed out\|connection refused\|no servers could be reached"; then
        echo "FAIL"
        return 1
    fi
    
    local query_time=$(echo "$dig_output" | grep "Query time:" | awk '{print $4}')
    local query_size=$(echo "$dig_output" | grep "Msg size" | awk '{print $NF}')
    local status=$(echo "$dig_output" | grep "STATUS:" | awk '{print $2}')
    
    if [[ -n "$query_time" ]]; then
        echo "${query_time}|${query_size}|${status}"
        return 0
    fi
    
    echo "FAIL|FAIL|FAIL"
    return 1
}

# Calculate average
calc_avg() {
    local sum=0
    local count=0
    for val in "$@"; do
        if [[ "$val" != "FAIL" ]] && [[ "$val" =~ ^[0-9]+$ ]]; then
            sum=$((sum + val))
            count=$((count + 1))
        fi
    done
    if [[ $count -gt 0 ]]; then
        echo $((sum / count))
    else
        echo "N/A"
    fi
}

################################################################################
# Print progress bar
################################################################################
print_progress() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))
    
    printf "\r${BLUE}["
    printf "%${filled}s" | tr ' ' '='
    printf "%${empty}s" | tr ' ' '-'
    printf "] %3d%%${NC}" "$percentage"
}

################################################################################
# Generate ASCII art banner
################################################################################
print_banner() {
    cat << 'EOF'

    ██████╗  █████╗ ████████╗ █████╗ 
    ██╔══██╗██╔══██╗╚══██╔══╝██╔══██╗
    ██║  ██║███████║   ██║   ███████║
    ██║  ██║██╔══██║   ██║   ██╔══██║
    ██████╔╝██║  ██║   ██║   ██║  ██║
    ╚═════╝ ╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝
                                        
    DNS Benchmark Tool v1.0
EOF
}

################################################################################
# Main Benchmark Function
################################################################################
RESULTS_FILE=$(mktemp)
STATS_FILE=$(mktemp)
trap 'rm -f "$RESULTS_FILE" "$STATS_FILE"' EXIT

run_benchmark() {
    local total_tests=$((${#DOMAINS[@]} * ${#DNS_SERVERS[@]} * ITERATIONS))
    local current_test=0
    local start_time=$(date +%s)

    echo -e "${YELLOW}Starting DNS benchmark...${NC}"
    echo ""

    # Test each DNS server
    for dns in "${DNS_SERVERS[@]}"; do
        echo -e "${GREEN}Testing DNS server: $dns${NC}"

        local dns_success=0
        local dns_total=0
        local all_times=()

        for domain in "${DOMAINS[@]}"; do
            [[ -z "$domain" ]] && continue

            for ((iter=1; iter<=ITERATIONS; iter++)); do
                current_test=$((current_test + 1))
                print_progress $current_test $total_tests

                local query_time=$(get_query_time "$domain" "$dns")

                if [[ "$query_time" != "FAIL" ]]; then
                    dns_success=$((dns_success + 1))
                    all_times+=("$query_time")
                fi
                echo "${dns}|${domain}|${iter}|${query_time}" >> "$RESULTS_FILE"

                dns_total=$((dns_total + 1))

                sleep 0.01
            done
        done

        # Calculate DNS server statistics
        if [[ ${#all_times[@]} -gt 0 ]]; then
            local success_rate=$((dns_success * 100 / dns_total))

            local min_val=${all_times[0]}
            local max_val=${all_times[0]}
            local sum=0

            for t in "${all_times[@]}"; do
                ((t < min_val)) && min_val=$t
                ((t > max_val)) && max_val=$t
                sum=$((sum + t))
            done

            local avg_val=$((sum / ${#all_times[@]}))
            echo "${dns}|${success_rate}|${avg_val}|${min_val}|${max_val}" >> "$STATS_FILE"
        else
            echo "${dns}|0|N/A|N/A|N/A" >> "$STATS_FILE"
        fi

        local avg_disp=$(tail -1 "$STATS_FILE" | cut -d'|' -f3)
        local min_disp=$(tail -1 "$STATS_FILE" | cut -d'|' -f4)
        local max_disp=$(tail -1 "$STATS_FILE" | cut -d'|' -f5)
        local sr_disp=$(tail -1 "$STATS_FILE" | cut -d'|' -f2)
        echo ""
        echo -e "  ${GREEN}Success rate: ${sr_disp}% | Avg: ${avg_disp}ms | Min: ${min_disp}ms | Max: ${max_disp}ms${NC}"
        echo ""
    done

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    echo -e "${GREEN}Benchmark completed in ${duration}s${NC}"
}

################################################################################
# Generate Report
################################################################################
generate_report() {
    {
        print_banner

        echo ""
        echo "═══════════════════════════════════════════════════════════════════════════════"
        echo "                           BENCHMARK REPORT"
        echo "═══════════════════════════════════════════════════════════════════════════════"
        echo ""
        echo "Generated: $(timestamp)"
        echo "Domains tested: ${#DOMAINS[@]}"
        echo "DNS servers tested: ${#DNS_SERVERS[@]}"
        echo "Iterations per domain: $ITERATIONS"
        echo "Timeout per query: ${TIMEOUT}s"
        echo ""

        # DNS Server Rankings
        echo "───────────────────────────────────────────────────────────────────────────────"
        echo "                           DNS SERVER RANKINGS"
        echo "───────────────────────────────────────────────────────────────────────────────"
        echo ""
        printf "%-20s %12s %10s %10s %10s %10s\n" "DNS Server" "Success Rate" "Avg (ms)" "Min (ms)" "Max (ms)" "Score"
        printf "%-20s %12s %10s %10s %10s %10s\n" "──────────" "────────────" "───────" "───────" "───────" "──────"

        # Build sorted list: score|dns|success|avg|min|max
        SORTED_FILE=$(mktemp)
        while IFS='|' read -r dns success avg min max; do
            local score=0
            if [[ "$avg" != "N/A" ]] && [[ "$avg" -gt 0 ]] 2>/dev/null; then
                score=$(echo "scale=2; $success * (1000 / $avg)" | bc 2>/dev/null || echo "0")
            fi
            echo "${score}|${dns}|${success}|${avg}|${min}|${max}"
        done < "$STATS_FILE" | sort -t'|' -k1 -rn > "$SORTED_FILE"

        while IFS='|' read -r score dns success avg min max; do
            printf "%-20s %10s%% %10s %10s %10s %10s\n" "$dns" "$success" "$avg" "$min" "$max" "$score"
        done < "$SORTED_FILE"

        echo ""
        echo "───────────────────────────────────────────────────────────────────────────────"
        echo "                          DETAILED RESULTS BY DOMAIN"
        echo "───────────────────────────────────────────────────────────────────────────────"

        for domain in "${DOMAINS[@]}"; do
            [[ -z "$domain" ]] && continue

            echo ""
            echo -e "${YELLOW}Domain: $domain${NC}"
            printf "%-20s %15s %15s %15s\n" "DNS Server" "Status" "IP Address" "Query Time"
            printf "%-20s %15s %15s %15s\n" "──────────" "──────────" "────────────" "───────────"

            for dns in "${DNS_SERVERS[@]}"; do
                local status="FAIL"
                local ip="N/A"
                local time="N/A"

                # Get first successful result from results file
                local first_ok=$(grep "^${dns}|${domain}|" "$RESULTS_FILE" | grep -v "|FAIL$" | head -1)
                if [[ -n "$first_ok" ]]; then
                    status="OK"
                    time=$(echo "$first_ok" | cut -d'|' -f4)" ms"
                    ip=$(resolve_with_dig "$domain" "$dns" | head -1)
                fi

                printf "%-20s %15s %15s %15s\n" "$dns" "$status" "$ip" "$time"
            done
        done

        echo ""
        echo "───────────────────────────────────────────────────────────────────────────────"
        echo "                            PERFORMANCE SUMMARY"
        echo "───────────────────────────────────────────────────────────────────────────────"
        echo ""

        local best_dns=$(head -1 "$SORTED_FILE" | cut -d'|' -f2)
        local best_avg=$(head -1 "$SORTED_FILE" | cut -d'|' -f4)
        local best_success=$(head -1 "$SORTED_FILE" | cut -d'|' -f3)
        echo "Best DNS Server: ${best_dns:-N/A}"
        echo "Average Response Time: ${best_avg:-N/A} ms"
        echo "Success Rate: ${best_success:-0}%"
        echo ""

        # Recommendation
        echo "───────────────────────────────────────────────────────────────────────────────"
        echo "                              RECOMMENDATION"
        echo "───────────────────────────────────────────────────────────────────────────────"
        echo ""

        if [[ -n "$best_dns" ]]; then
            echo "Based on this benchmark, ${best_dns} is recommended for:"
            echo "  - Fastest average response time: ${best_avg}ms"
            echo "  - Highest reliability: ${best_success}% success rate"
            echo ""
            echo "To use this DNS server, add the following to your network settings:"
            echo "  Primary DNS:   $best_dns"
        fi

        echo ""
        echo "═══════════════════════════════════════════════════════════════════════════════"
        echo "                            END OF REPORT"
        echo "═══════════════════════════════════════════════════════════════════════════════"

        rm -f "$SORTED_FILE"

    } | tee "$OUTPUT_FILE"

    echo ""
    echo -e "${GREEN}Report saved to: $OUTPUT_FILE${NC}"
}

################################################################################
# Main Execution
################################################################################
main() {
    print_banner
    echo ""
    
    echo -e "${BLUE}Configuration:${NC}"
    echo "  Domains file: $DOMAINS_FILE"
    echo "  DNS servers file: $DNS_FILE"
    echo "  Timeout: ${TIMEOUT}s"
    echo "  Iterations: $ITERATIONS"
    echo ""
    
    # Check for required tools
    if ! command -v dig &> /dev/null; then
        echo -e "${RED}Error: 'dig' is required but not installed.${NC}"
        echo "Install with: apt-get install dnsutils (Debian/Ubuntu) or brew install bind (macOS)"
        exit 1
    fi
    
    if ! command -v bc &> /dev/null; then
        echo -e "${YELLOW}Warning: 'bc' not found. Score calculation may be limited.${NC}"
    fi
    
    run_benchmark
    generate_report
}

main
