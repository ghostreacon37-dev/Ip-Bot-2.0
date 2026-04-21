#!/usr/bin/bash

# Configuration
API_URL="https://api.proxyscrape.com/v4/free-proxy-list/get?request=display_proxies&proxy_format=protocolipport&format=text"
WORK_DIR="Ip-bot-2.0"
TIMEOUT=5
BATCH_SIZE=100
MAX_RETRIES=3
SLEEP_BETWEEN_CYCLES=300  # 5 minutes between cycles
SLEEP_BETWEEN_BATCHES=2   # Small pause between batches

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check dependencies
if ! command -v curl &> /dev/null; then
    echo -e "${RED}Error: curl is not installed${NC}"
    exit 1
fi

# Create working directory
mkdir -p "$WORK_DIR" || { echo -e "${RED}Error: Cannot create directory $WORK_DIR${NC}"; exit 1; }

# Function to fetch proxy list with retries and better error handling
fetch_proxies() {
    local attempt=1
    local temp_file=$(mktemp)
    local error_file=$(mktemp)
    
    while [ $attempt -le $MAX_RETRIES ]; do
        echo -e "${YELLOW}Attempt $attempt/$MAX_RETRIES: Fetching fresh proxy list...${NC}"
        
        # Fetch with proper headers, following redirects, ignoring SSL errors (some systems have cert issues)
        local http_code
        http_code=$(curl -L -s --max-time 60 \
            -w "%{http_code}" \
            -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" \
            -H "Accept: text/plain,*/*" \
            -H "Cache-Control: no-cache, no-store, must-revalidate" \
            -H "Pragma: no-cache" \
            -o "$temp_file" \
            "$API_URL" 2>"$error_file")
        
        curl_exit=$?
        
        if [ $curl_exit -eq 0 ] && [ "$http_code" == "200" ]; then
            if [ -s "$temp_file" ]; then
                # Remove carriage returns and empty lines
                sed 's/\r$//; /^$/d' "$temp_file" > proxy_list.raw 2>/dev/null
                local count=$(wc -l < proxy_list.raw)
                if [ $count -gt 0 ]; then
                    echo -e "${GREEN}Successfully fetched $count proxies${NC}"
                    rm -f "$temp_file" "$error_file"
                    return 0
                else
                    echo -e "${RED}Error: File is empty after cleaning${NC}"
                fi
            else
                echo -e "${RED}Error: Downloaded file is empty (HTTP $http_code)${NC}"
            fi
        else
            echo -e "${RED}Error: curl failed (exit: $curl_exit, HTTP: $http_code)${NC}"
            if [ -s "$error_file" ]; then
                echo -e "${RED}Details: $(head -c 200 "$error_file")${NC}"
            fi
        fi
        
        attempt=$((attempt + 1))
        [ $attempt -le $MAX_RETRIES ] && { echo -e "${YELLOW}Retrying in 5 seconds...${NC}"; sleep 5; }
    done
    
    rm -f "$temp_file" "$error_file"
    return 1
}

# Function to check individual proxy (writes to temp files to avoid lock issues)
check_proxy() {
    local proxy_line="$1"
    local protocol=""
    local address=""
    local pid=$$
    local temp_suffix="${pid}_$(echo "$proxy_line" | tr -d ':/')"
    
    # Parse protocol://ip:port format
    if [[ "$proxy_line" =~ ^([a-zA-Z0-9]+)://(.+)$ ]]; then
        protocol="${BASH_REMATCH[1]}"
        address="${BASH_REMATCH[2]}"
    else
        return
    fi
    
    local test_url="http://httpbin.org/ip"
    local status=""
    local working=0
    
    case "$protocol" in
        http)
            status=$(curl -x "http://$address" --connect-timeout $TIMEOUT --max-time 10 \
                -s -o /dev/null -w "%{http_code}" \
                -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" \
                "$test_url" 2>/dev/null)
            [ "$status" == "200" ] && { echo "$proxy_line" >> "http.tmp.$temp_suffix"; working=1; }
            ;;
            
        https)
            status=$(curl -x "https://$address" --connect-timeout $TIMEOUT --max-time 10 \
                -s -o /dev/null -w "%{http_code}" \
                -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" \
                "https://httpbin.org/ip" 2>/dev/null)
            [ "$status" == "200" ] && { echo "$proxy_line" >> "https.tmp.$temp_suffix"; working=1; }
            ;;
            
        socks4|socks4a)
            status=$(curl --socks4 "$address" --connect-timeout $TIMEOUT --max-time 10 \
                -s -o /dev/null -w "%{http_code}" \
                -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" \
                "$test_url" 2>/dev/null)
            [ "$status" == "200" ] && { echo "$proxy_line" >> "socks4.tmp.$temp_suffix"; working=1; }
            ;;
            
        socks5)
            status=$(curl --socks5 "$address" --connect-timeout $TIMEOUT --max-time 10 \
                -s -o /dev/null -w "%{http_code}" \
                -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" \
                "$test_url" 2>/dev/null)
            [ "$status" == "200" ] && { echo "$proxy_line" >> "socks5.tmp.$temp_suffix"; working=1; }
            ;;
    esac
    
    # Output to console (colored)
    if [ $working -eq 1 ]; then
        echo -e "${GREEN}[✓]${NC} $protocol://${address} (${status})"
    else
        echo -e "${RED}[✗]${NC} $protocol://${address} ${BLUE}(${status:-timeout})${NC}"
    fi
}

# Function to merge temp files into main files
merge_batch_results() {
    for proto in http https socks4 socks5; do
        if ls ${proto}.tmp.* 1> /dev/null 2>&1; then
            cat ${proto}.tmp.* >> "${proto}.txt"
            rm -f ${proto}.tmp.*
        fi
    done
}

# Cleanup function
cleanup() {
    echo -e "\n${YELLOW}Cleaning up...${NC}"
    kill $(jobs -p) 2>/dev/null
    wait 2>/dev/null
    rm -f *.tmp.* proxy_list.raw 2>/dev/null
    exit 0
}

trap cleanup EXIT INT TERM

# Main infinite loop
cycle=1
while true; do
    echo -e "\n========================================"
    echo -e "${YELLOW}CYCLE $cycle started at $(date '+%Y-%m-%d %H:%M:%S')${NC}"
    echo -e "========================================"
    
    cd "$WORK_DIR" || exit 1
    
    # Clear previous files
    echo -e "${YELLOW}Clearing previous results...${NC}"
    > http.txt 2>/dev/null || true
    > https.txt 2>/dev/null || true
    > socks4.txt 2>/dev/null || true
    > socks5.txt 2>/dev/null || true
    rm -f *.tmp.* 2>/dev/null
    
    # Fetch proxy list
    if ! fetch_proxies; then
        echo -e "${RED}Failed to fetch proxy list after $MAX_RETRIES attempts${NC}"
        echo -e "${YELLOW}Waiting $SLEEP_BETWEEN_CYCLES seconds before retry...${NC}"
        cd ..
        sleep $SLEEP_BETWEEN_CYCLES
        cycle=$((cycle + 1))
        continue
    fi
    
    total=$(wc -l < proxy_list.raw)
    echo -e "${BLUE}Total proxies to check: $total${NC}"
    echo -e "${YELLOW}Processing in batches of $BATCH_SIZE (this prevents system overload)...${NC}\n"
    
    # Process in batches of 100
    current_batch=0
    total_checked=0
    batch_num=0
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "$line" ]] && continue
        
        check_proxy "$line" &
        
        current_batch=$((current_batch + 1))
        total_checked=$((total_checked + 1))
        
        # When batch reaches 100, wait for completion then merge
        if [ $current_batch -ge $BATCH_SIZE ]; then
            batch_num=$((batch_num + 1))
            echo -e "\n${YELLOW}>>> Batch $batch_num complete ($total_checked/$total). Merging results...${NC}"
            wait
            merge_batch_results
            
            # Show interim stats
            h=$(wc -l < http.txt 2>/dev/null || echo 0)
            hs=$(wc -l < https.txt 2>/dev/null || echo 0)
            s4=$(wc -l < socks4.txt 2>/dev/null || echo 0)
            s5=$(wc -l < socks5.txt 2>/dev/null || echo 0)
            echo -e "${GREEN}Working so far: HTTP=$h HTTPS=$hs SOCKS4=$s4 SOCKS5=$s5${NC}"
            
            sleep $SLEEP_BETWEEN_BATCHES
            current_batch=0
        fi
        
        # Progress bar every 10 proxies
        if [ $((total_checked % 10)) -eq 0 ]; then
            printf "${BLUE}Progress: %d/%d (%d%%)${NC}\r" $total_checked $total $((total_checked * 100 / total))
        fi
        
    done < proxy_list.raw
    
    # Process remaining proxies in last incomplete batch
    if [ $current_batch -gt 0 ]; then
        echo -e "\n${YELLOW}>>> Processing final batch...${NC}"
        wait
        merge_batch_results
    fi
    
    rm -f proxy_list.raw
    
    # Final statistics
    http_count=$(wc -l < http.txt 2>/dev/null || echo 0)
    https_count=$(wc -l < https.txt 2>/dev/null || echo 0)
    socks4_count=$(wc -l < socks4.txt 2>/dev/null || echo 0)
    socks5_count=$(wc -l < socks5.txt 2>/dev/null || echo 0)
    total_working=$((http_count + https_count + socks4_count + socks5_count))
    
    echo -e "\n========================================"
    echo -e "${GREEN}CYCLE $cycle COMPLETED${NC}"
    echo -e "Time: $(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "========================================"
    echo -e "Results saved in $(pwd)/"
    echo -e "  ${GREEN}http.txt${NC}   : $http_count working proxies"
    echo -e "  ${GREEN}https.txt${NC}  : $https_count working proxies"
    echo -e "  ${GREEN}socks4.txt${NC} : $socks4_count working proxies"
    echo -e "  ${GREEN}socks5.txt${NC} : $socks5_count working proxies"
    echo -e "----------------------------------------"
    echo -e "Total working: ${GREEN}$total_working${NC} / $total checked"
    echo -e "Success rate: ${GREEN}$(awk "BEGIN {printf \"%.2f\", ($total_working/$total)*100}")%${NC}"
    echo -e "========================================"
    
    cd ..
    
    echo -e "${YELLOW}Waiting $SLEEP_BETWEEN_CYCLES seconds before fetching fresh list...${NC}"
    echo -e "${BLUE}Press Ctrl+C to stop${NC}\n"
    sleep $SLEEP_BETWEEN_CYCLES
    cycle=$((cycle + 1))
    
done
