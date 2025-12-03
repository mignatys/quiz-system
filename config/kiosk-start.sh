#!/bin/bash
export DISPLAY=:0
epiphany-browser --profile ~/.config/epiphany --display=:0 --fullscreen --incognito http://localhost:5000
