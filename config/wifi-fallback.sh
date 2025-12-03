#!/bin/bash

SSID=$(iwgetid -r)

if [ -z "$SSID" ]; then
    echo "No Wi-Fi, starting setup AP..."
    nmcli device wifi hotspot ssid "QuizSetup" password "12345678"
else
    echo "Connected to Wi-Fi: $SSID"
fi

