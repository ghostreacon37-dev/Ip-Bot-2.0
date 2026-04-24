#!/bin/bash

# --- CONFIGURATION ---
FOLDER="Ip-bot-2.0"
FILES=("http.txt" "socks4.txt" "socks5.txt")

# Define Tiers (Country Codes) - Expanded lists to prevent skipping
TIER1=("US" "GB" "CA" "AU" "DE" "FR" "JP" "KR" "IT" "ES" "NL" "SE" "NO" "DK" "FI" "NZ" "IE" "BE" "CH" "AT")
TIER2=("BR" "RU" "IN" "CN" "MX" "ID" "TR" "VN" "PH" "MY" "AR" "CL" "CO" "ZA" "EG" "NG" "PK" "TH" "SA" "MA")

# We use a loop to keep trying until a working proxy is found
while true; do
    # 1. Randomly select one of the files from the array
    SELECTED_FILE=${FILES[$RANDOM % ${#FILES[@]}]}
    FILE_PATH="$FOLDER/$SELECTED_FILE"

    # Check if the folder and file actually exist
    if [ ! -f "$FILE_PATH" ]; then
        echo "[-] Error: File $FILE_PATH not found. Skipping..."
        continue # Try another file
    fi

    # 2. Pick a random line (proxy) from that file
    PROXY_LINE=$(shuf -n 1 "$FILE_PATH")

    if [ -z "$PROXY_LINE" ]; then
        echo "[-] Error: Selected file is empty. Skipping..."
        continue # Try another file
    fi

    echo "[*] Testing Proxy: $PROXY_LINE"

    # --- CHECK LOGIC START ---
    # 1. Basic Connectivity Check (Google)
    if curl -s --proxy "$PROXY_LINE" --max-time 5 -I https://www.google.com > /dev/null; then
        
        # 3. Tier/Country Probability Check
        # Get country code of the proxy
        COUNTRY=$(curl -s --proxy "$PROXY_LINE" --max-time 5 http://ip-api.com/line/?fields=countryCode)
        
        # Determine which tier we want based on probability
        # 0-84 (85%) = Tier 1 | 85-94 (10%) = Tier 2 | 95-99 (5%) = Tier 3
        ROLL=$((RANDOM % 100))
        
        if [ $ROLL -lt 85 ]; then
            # We want a T1 proxy
            if [[ " ${TIER1[*]} " =~ " $COUNTRY " ]]; then
                echo "[+] Valid Tier 1 Proxy ($COUNTRY)!"
                break 
            else
                echo "[-] Wanted Tier 1, but got $COUNTRY. Skipping..."
                continue
            fi
        elif [ $ROLL -lt 95 ]; then
            # We want a T2 proxy
            if [[ " ${TIER2[*]} " =~ " $COUNTRY " ]]; then
                echo "[+] Valid Tier 2 Proxy ($COUNTRY)!"
                break
            else
                echo "[-] Wanted Tier 2, but got $COUNTRY. Skipping..."
                continue
            fi
        else
            # We want a T3 proxy (Any country not in T1 or T2)
            if [[ ! " ${TIER1[*]} " =~ " $COUNTRY " ]] && [[ ! " ${TIER2[*]} " =~ " $COUNTRY " ]]; then
                echo "[+] Valid Tier 3 Proxy ($COUNTRY)!"
                break
            else
                echo "[-] Wanted Tier 3, but got T1/T2. Skipping..."
                continue
            fi
        fi

    else
        echo "[-] Proxy is DEAD. Trying another one..."
        # The loop continues and picks a new random proxy
    fi
    # --- CHECK LOGIC END ---

done

# -----------------------------------------------------------------
# ALL ORIGINAL LOGIC BELOW (Applied only if the loop was broken by a working proxy)
# -----------------------------------------------------------------

echo "[*] Selected File: $SELECTED_FILE"
echo "[*] Selected Proxy: $PROXY_LINE"

# 3. Parse the proxy string (Removes protocol:// and splits ip:port)
CLEAN_PROXY=$(echo "$PROXY_LINE" | sed -E 's|^.*://||')

# Split the remaining ip:port into variables
PROXY_HOST=$(echo "$CLEAN_PROXY" | cut -d: -f1)
PROXY_PORT=$(echo "$CLEAN_PROXY" | cut -d: -f2)

# 4. Apply to GNOME Settings
gsettings set org.gnome.system.proxy mode 'manual'

if [ "$SELECTED_FILE" == "http.txt" ]; then
    echo "[+] Applying HTTP Proxy..."
    gsettings set org.gnome.system.proxy.http host "$PROXY_HOST"
    gsettings set org.gnome.system.proxy.http port "$PROXY_PORT"
    gsettings set org.gnome.system.proxy.socks host ""
    gsettings set org.gnome.system.proxy.socks port 0
elif [[ "$SELECTED_FILE" == "socks4.txt" || "$SELECTED_FILE" == "socks5.txt" ]]; then
    echo "[+] Applying SOCKS Proxy..."
    gsettings set org.gnome.system.proxy.socks host "$PROXY_HOST"
    gsettings set org.gnome.system.proxy.socks port "$PROXY_PORT"
    gsettings set org.gnome.system.proxy.http host ""
    gsettings set org.gnome.system.proxy.http port 0
fi

echo "[SUCCESS] System proxy has been changed to $PROXY_HOST:$PROXY_PORT"
