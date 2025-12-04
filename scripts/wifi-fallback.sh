#!/bin/bash

SSID=$(iwgetid -r)
HOTSPOT_ACTIVE=$(nmcli connection show --active | grep -c "QuizSetup")

if [ -z "$SSID" ]; then
    if [ "$HOTSPOT_ACTIVE" -eq 0 ]; then
        echo "No Wi-Fi, starting setup AP..."
        nmcli device wifi hotspot ssid "QuizSetup" password "12345678"
    else
        echo "Hotspot already active."
    fi
else
    echo "Connected to Wi-Fi: $SSID"
    if [ "$HOTSPOT_ACTIVE" -gt 0 ]; then
        echo "Deactivating hotspot."
        nmcli connection down "QuizSetup"
    fi
fi
