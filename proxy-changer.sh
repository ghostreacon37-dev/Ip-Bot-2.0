#!/bin/bash

# Path to your script
SCRIPT_PATH="./PROXY-CHANGER.sh"

echo "Loop started. Triggering $SCRIPT_PATH every 10 minutes."

while true
do
    # Check if the file exists and is executable
    if [ -x "$SCRIPT_PATH" ]; then
        bash "$SCRIPT_PATH"
        echo "Executed at $(date)"
    else
        echo "Error: $SCRIPT_PATH not found or not executable."
    fi

    # Wait for 10 minutes (600 seconds)
    sleep 600
done
