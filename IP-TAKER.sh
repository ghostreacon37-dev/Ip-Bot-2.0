#!/bin/bash

URL="https://api.proxyscrape.com/v4/free-proxy-list/get?request=display_proxies&proxy_format=protocolipport&format=text"

ALL="proxy_ip.txt"

mkdir -p workingproxy
> workingproxy/http.txt
> workingproxy/https.txt
> workingproxy/socks4.txt
> workingproxy/socks5.txt

# Step 1: Fetch (KEEP protocol)
curl -s "$URL" > "$ALL"

echo "[+] Extracted $(wc -l < "$ALL") proxies"
echo

# Step 2: Check proxies
while read -r proxy; do
    echo -n "Checking $proxy ... "

    working=0

    if [[ $proxy == http://* ]]; then
        if curl -s --proxy "$proxy" --max-time 5 https://api.ipify.org >/dev/null 2>&1; then
            echo "$proxy" >> workingproxy/http.txt
            working=1
        fi

    elif [[ $proxy == socks4://* ]]; then
        if curl -s --proxy "$proxy" --socks4 --max-time 5 https://api.ipify.org >/dev/null 2>&1; then
            echo "$proxy" >> workingproxy/socks4.txt
            working=1
        fi

    elif [[ $proxy == socks5://* ]]; then
        if curl -s --proxy "$proxy" --socks5 --max-time 5 https://api.ipify.org >/dev/null 2>&1; then
            echo "$proxy" >> workingproxy/socks5.txt
            working=1
        fi
    fi

    if [ "$working" -eq 1 ]; then
        echo "WORKING"
    else
        echo "DEAD"
    fi

done < "$ALL"

echo
echo "[+] HTTP working proxies  : $(wc -l < workingproxy/http.txt 2>/dev/null || echo 0)"
echo "[+] SOCKS4 working proxies: $(wc -l < workingproxy/socks4.txt 2>/dev/null || echo 0)"
echo "[+] SOCKS5 working proxies: $(wc -l < workingproxy/socks5.txt 2>/dev/null || echo 0)"
