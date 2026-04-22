#!/bin/bash
sudo apt install gnome-terminal -y
chmod +x IP-TAKER.sh PROXY-CHANGER.sh proxy-changer.sh
gnome-terminal -- bash -c "./IP-TAKER.sh; exec bash"
gnome-terminal -- bash -c "./proxy-changer.sh; exec bash"
