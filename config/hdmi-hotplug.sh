#!/bin/bash
sleep 1
HDMI_STATUS=$(tvservice -s | grep -c "0x1200")

if [ "$HDMI_STATUS" -gt 0 ]; then
    pkill -f "python /opt/quiz/run.py" || true
    if ! pgrep -x lxsession > /dev/null; then
        startx /usr/local/bin/kiosk-start.sh &
    fi
else
    pkill -f epiphany-browser || true
    pkill -x lxsession || true
    source /opt/quiz-venv/bin/activate
    if ! pgrep -f "python /opt/quiz/run.py" > /dev/null; then
        nohup python /opt/quiz/run.py > /opt/quiz/log.txt 2>&1 &
    fi
    # Optional: start BT audio
fi
