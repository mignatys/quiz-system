#!/bin/bash
set -e

echo "=== Updating system ==="
sudo apt-get update -y
sudo apt-get upgrade -y

echo "=== Installing APT packages ==="
while read pkg; do
    sudo apt-get install -y "$pkg"
done < apt-packages.txt

echo "=== Creating Python virtual environment ==="
python3 -m venv /opt/quiz-venv
source /opt/quiz-venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

echo "=== Copying application to /opt/quiz ==="
sudo mkdir -p /opt/quiz
sudo cp -r app/* /opt/quiz

echo "=== Installing systemd services ==="
sudo cp config/quiz.service /etc/systemd/system/
sudo cp config/wifi-fallback.service /etc/systemd/system/

echo "=== Copying scripts ==="
sudo chmod +x config/kiosk-start.sh
sudo cp config/kiosk-start.sh /usr/local/bin/

sudo chmod +x config/wifi-fallback.sh
sudo cp config/wifi-fallback.sh /usr/local/bin/

sudo chmod +x config/hdmi-hotplug.sh
sudo cp config/hdmi-hotplug.sh /usr/local/bin/

sudo systemctl daemon-reload

echo "=== Enabling services ==="
sudo systemctl enable quiz
sudo systemctl enable wifi-fallback

echo "=== Enabling SSH ==="
sudo systemctl enable ssh
sudo systemctl start ssh

echo "=== Creating LXDE autostart for kiosk mode ==="
mkdir -p ~/.config/lxsession/LXDE
cat <<EOL > ~/.config/lxsession/LXDE/autostart
@xset s off
@xset -dpms
@xset s noblank
@/usr/local/bin/kiosk-start.sh
EOL

echo "=== Installing HDMI hotplug auto-switch ==="
sudo tee /etc/udev/rules.d/99-hdmi-hotplug.rules > /dev/null <<EOL
SUBSYSTEM=="drm", KERNEL=="card0", ENV{HOTPLUG}=="1", ACTION=="change", RUN+="/usr/local/bin/hdmi-hotplug.sh"
EOL

sudo udevadm control --reload-rules
sudo udevadm trigger

echo "=== Installation finished ==="
echo "Reboot recommended: sudo reboot"
