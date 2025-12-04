#!/bin/bash
set -e

# --- User and Directory Setup ---
if [ "$SUDO_USER" ]; then
    REAL_USER="$SUDO_USER"
else
    REAL_USER=$(whoami)
fi
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
DEST_DIR="/opt/quiz"
MM_DIR="/home/$REAL_USER/MagicMirror"

echo "Running installation as user: $REAL_USER"

# --- System Dependencies ---
echo "=== Updating system and installing APT packages ==="
#sudo apt-get update -y && sudo apt-get upgrade -y
#sudo apt-get purge -y nodejs npm || true
#sudo apt-get autoremove -y
cat "$SCRIPT_DIR/apt-packages.txt" | xargs sudo apt-get install -y

# --- Node.js & MagicMirror Installation via nvm ---
echo "=== Installing Node.js and MagicMirror for user $REAL_USER ==="
sudo -u "$REAL_USER" bash -c '
    set -e
    export NVM_DIR="$HOME/.nvm"
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    nvm install 22
    if [ ! -d "'"$MM_DIR"'" ]; then
        git clone https://github.com/MagicMirrorOrg/MagicMirror.git "'"$MM_DIR"'"
    fi
    cd "'"$MM_DIR"'"
    nvm use 22 && npm install --no-fund --no-audit
'

# --- Configure MagicMirror ---
echo "=== Configuring MagicMirror ==="
CONFIG_JS_PATH="$MM_DIR/config/config.js"
sudo -u "$REAL_USER" bash -c '
    set -e
    if [ ! -f "'"$CONFIG_JS_PATH"'" ]; then
        cp "'"$MM_DIR/config/config.js.sample"'" "'"$CONFIG_JS_PATH"'"
    fi
    if ! grep -q "\"QuizGame\"" "'"$CONFIG_JS_PATH"'"; then
        sed -i "/modules: \[/a \ \ \ \ \ \ \ \ {\n\t\t\tmodule: \"QuizGame\",\n\t\t\tposition: \"middle_center\",\n\t\t}," "'"$CONFIG_JS_PATH"'"
    fi
'

# --- Project Deployment & Linking ---
echo "=== Syncing project files and linking module ==="
sudo mkdir -p "$DEST_DIR"
sudo chown "$REAL_USER:$REAL_USER" "$DEST_DIR"
sudo -u "$REAL_USER" rsync -a --delete "$SCRIPT_DIR/" "$DEST_DIR/" --exclude ".git/" --exclude ".idea/" --exclude ".venv/"
MODULE_NAME="QuizGame"
sudo -u "$REAL_USER" ln -sfn "$DEST_DIR/ui/$MODULE_NAME" "$MM_DIR/modules/$MODULE_NAME"

# --- Python Environment ---
echo "=== Setting up Python virtual environment ==="
sudo -u "$REAL_USER" python3 -m venv "$DEST_DIR/venv"
sudo -u "$REAL_USER" "$DEST_DIR/venv/bin/pip" install -r "$DEST_DIR/requirements.txt"

# --- Auto-Login Kiosk Setup ---
echo "=== Setting up Auto-Login Kiosk Mode ==="
# 1. Configure systemd to auto-login the user on the main console (tty1)
sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
sudo tee /etc/systemd/system/getty@tty1.service.d/override.conf > /dev/null <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $REAL_USER --noclear %I \$TERM
EOF

# 2. Add UI auto-start logic to the user's profile
sudo -u "$REAL_USER" tee -a "/home/$REAL_USER/.bash_profile" > /dev/null <<'EOF'

# If running on the main console (tty1) and no UI is running, start it.
if [ -z "$DISPLAY" ] && [ "$(fgconsole)" -eq 1 ]; then
  # Source nvm to make npm available
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  startx
fi
EOF

# 3. Create the .xinitrc file to define what the UI is
sudo -u "$REAL_USER" tee "/home/$REAL_USER/.xinitrc" > /dev/null <<'EOF'
#!/bin/bash
# Hide the mouse cursor
unclutter -idle 1 -root &
# Start MagicMirror
cd ~/MagicMirror
npm start
EOF

# --- Backend Service ---
echo "=== Installing systemd service for Flask Backend ==="
sudo sed "s/PI_USER/$REAL_USER/g" "$DEST_DIR/systemd/quiz.service" | sudo tee /etc/systemd/system/quiz.service > /dev/null
sudo systemctl daemon-reload
sudo systemctl enable quiz.service

echo "=== Installation finished ==="
echo "The system is now configured for Auto-Login Kiosk mode."
echo "After reboot, the system should log in and start the UI automatically."
