#!/bin/bash

# --- CONFIGURATION ---
# Path to your folder. If it's in the same directory as the script, leave as is.
FOLDER="Ip-bot-2.0"

# List of files to choose from
FILES=("http.txt" "socks4.txt" "socks5.txt")

# 1. Randomly select one of the files from the array
SELECTED_FILE=${FILES[$RANDOM % ${#FILES[@]}]}
FILE_PATH="$FOLDER/$SELECTED_FILE"

# Check if the folder and file actually exist
if [ ! -f "$FILE_PATH" ]; then
    echo "[-] Error: File $FILE_PATH not found."
    exit 1
fi

# 2. Pick a random line (proxy) from that file
PROXY_LINE=$(shuf -n 1 "$FILE_PATH")

if [ -z "$PROXY_LINE" ]; then
    echo "[-] Error: Selected file is empty."
    exit 1
fi

echo "[*] Selected File: $SELECTED_FILE"
echo "[*] Selected Proxy: $PROXY_LINE"

# 3. Parse the proxy string (Removes protocol:// and splits ip:port)
# This removes everything up to the //
CLEAN_PROXY=$(echo "$PROXY_LINE" | sed -E 's|^.*://||')

# Split the remaining ip:port into variables
PROXY_HOST=$(echo "$CLEAN_PROXY" | cut -d: -f1)
PROXY_PORT=$(echo "$CLEAN_PROXY" | cut -d: -f2)

# 4. Apply to GNOME Settings
# Set proxy mode to 'manual' first
gsettings set org.gnome.system.proxy mode 'manual'

if [ "$SELECTED_FILE" == "http.txt" ]; then
    echo "[+] Applying HTTP Proxy..."
    # Set HTTP
    gsettings set org.gnome.system.proxy.http host "$PROXY_HOST"
    gsettings set org.gnome.system.proxy.http port "$PROXY_PORT"
    # Clear SOCKS to prevent conflicts
    gsettings set org.gnome.system.proxy.socks host ""
    gsettings set org.gnome.system.proxy.socks port 0
elif [[ "$SELECTED_FILE" == "socks4.txt" || "$SELECTED_FILE" == "socks5.txt" ]]; then
    echo "[+] Applying SOCKS Proxy..."
    # Set SOCKS
    gsettings set org.gnome.system.proxy.socks host "$PROXY_HOST"
    gsettings set org.gnome.system.proxy.socks port "$PROXY_PORT"
    # Clear HTTP to prevent conflicts
    gsettings set org.gnome.system.proxy.http host ""
    gsettings set org.gnome.system.proxy.http port 0
fi

echo "[SUCCESS] System proxy has been changed to $PROXY_HOST:$PROXY_PORT"
