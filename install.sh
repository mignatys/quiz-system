#!/bin/bash
set -e

# --- User and Directory Setup ---
if [ "$SUDO_USER" ]; then
    REAL_USER="$SUDO_USER"
else
    REAL_USER=$(whoami)
fi
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
# MagicMirror is now a local submodule
MM_DIR="$SCRIPT_DIR/magicmirror" 
# The final running location for MagicMirror
MM_DEST_DIR="/home/$REAL_USER/MagicMirror" 

echo "Running installation as user: $REAL_USER"

# --- Grant Hardware Access ---
echo "=== Adding user $REAL_USER to the 'video' and 'input' groups for hardware access ==="
sudo usermod -a -G video,input "$REAL_USER"

# --- System Dependencies ---
echo "=== Installing APT packages ==="
cat "$SCRIPT_DIR/apt-packages.txt" | xargs sudo apt-get install -y

# --- MagicMirror Submodule ---
echo "=== Initializing MagicMirror submodule ==="
# Check if the submodule directory is empty, and initialize if needed
if [ ! -d "$MM_DIR" ] || [ -z "$(ls -A "$MM_DIR")" ]; then
    git submodule update --init --recursive
fi

# --- Node.js & MagicMirror Installation via nvm ---
echo "=== Installing Node.js and MagicMirror for user $REAL_USER ==="
# Copy the submodule code to the user's home directory
sudo -u "$REAL_USER" mkdir -p "$MM_DEST_DIR"
sudo -u "$REAL_USER" rsync -a --delete "$MM_DIR/" "$MM_DEST_DIR/"

sudo -u "$REAL_USER" bash -c '
    set -e
    export NVM_DIR="$HOME/.nvm"
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    nvm install 22
    cd "'"$MM_DEST_DIR"'"
    nvm use 22 && npm install --no-fund --no-audit
'

# --- Configure MagicMirror (Now using local files) ---
echo "=== Configuring MagicMirror ==="
CONFIG_JS_PATH="$MM_DEST_DIR/config/config.js"
# Create a clean config from the sample in our submodule
sudo -u "$REAL_USER" bash -c '
    set -e
    # Start with a fresh copy of the sample config
    cp "'"$MM_DIR/config/config.js.sample"'" "'"$CONFIG_JS_PATH"'"
    
    # Edit the config to only include our module
    sed -i "/modules: \[/a \ \ \ \ \ \ \ \ {\n\t\t\tmodule: \"QuizGame\",\n\t\t\tposition: \"middle_center\",\n\t\t}," "'"$CONFIG_JS_PATH"'"
    
    # Remove all other modules between the initial bracket and our module
    sed -i "/modules: \[/,/module: \"QuizGame\"/ { /module: \"QuizGame\"/! { /^{/d; /},$/d; } }" "'"$CONFIG_JS_PATH"'"
    
    # Remove all modules after our module
    sed -i "/module: \"QuizGame\"/,/\]/ { /module: \"QuizGame\"/! { /^{/d; /},$/d; } }" "'"$CONFIG_IS_PATH"'"
'

# --- Project Deployment & Linking ---
echo "=== Syncing project files and linking module ==="
DEST_DIR="/opt/quiz"
sudo mkdir -p "$DEST_DIR"
sudo chown "$REAL_USER:$REAL_USER" "$DEST_DIR"
sudo -u "$REAL_USER" rsync -a --delete "$SCRIPT_DIR/" "$DEST_DIR/" --exclude ".git/" --exclude ".idea/" --exclude ".venv/" --exclude "magicmirror/"
MODULE_NAME="QuizGame"
sudo -u "$REAL_USER" ln -sfn "$DEST_DIR/ui/$MODULE_NAME" "$MM_DEST_DIR/modules/$MODULE_NAME"

# --- Python Environment ---
echo "=== Setting up Python virtual environment ==="
sudo -u "$REAL_USER" python3 -m venv "$DEST_DIR/venv"
sudo -u "$REAL_USER" "$DEST_DIR/venv/bin/pip" install -r "$DEST_DIR/requirements.txt"

# --- Auto-Login Kiosk Setup ---
echo "=== Setting up Auto-Login Kiosk Mode for DietPi ==="
sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
sudo tee /etc/systemd/system/getty@tty1.service.d/override.conf > /dev/null <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $REAL_USER --noclear %I \$TERM
EOF

sudo -u "$REAL_USER" tee "/home/$REAL_USER/.profile" > /dev/null <<'EOF'
if [ -z "$DISPLAY" ] && [ "$(fgconsole 2>/dev/null || echo 1)" -eq 1 ]; then
  startx
fi
EOF

sudo -u "$REAL_USER" tee "/home/$REAL_USER/.xinitrc" > /dev/null <<'EOF'
#!/bin/bash
exec > ${HOME}/xinit.log 2>&1
echo "--- .xinitrc started at $(date) ---"
export DISPLAY=:0
eval $(dbus-launch --sh-syntax)
pulseaudio --start
unclutter -idle 1 -root &
export NVM_DIR="${HOME}/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
cd "${HOME}/MagicMirror"
echo "Starting MagicMirror..."
/usr/bin/openbox-session &
npm start
echo "--- MagicMirror process exited at $(date) ---"
EOF

# --- Backend Service ---
echo "=== Installing systemd service for Flask Backend ==="
sudo sed "s/PI_USER/$REAL_USER/g" "$DEST_DIR/systemd/quiz.service" | sudo tee /etc/systemd/system/quiz.service > /dev/null
sudo systemctl daemon-reload
sudo systemctl enable quiz.service

echo "=== Installation finished ==="
echo "Rebooting now..."
sudo reboot
