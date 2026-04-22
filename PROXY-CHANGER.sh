#!/bin/bash

# --- CONFIGURATION ---
FOLDER="Ip-bot-2.0"
FILES=("http.txt" "socks4.txt" "socks5.txt")

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
    # We use curl to check if the proxy is working.
    # --proxy: uses the proxy string (e.g., http://1.2.3.4:8080)
    # --max-time 5: gives the proxy 5 seconds to respond before giving up
    # -s: silent mode
    # -I: fetch headers only (faster)
    if curl -s --proxy "$PROXY_LINE" --max-time 5 -I https://www.google.com > /dev/null; then
        echo "[+] Proxy is WORKING!"
        # BREAK the loop because we found a working proxy
        break 
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
