#!/bin/bash
set -e

# --- Environment Setup ---
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
DEST_DIR="/opt/quiz"

if [ ! -d "$DEST_DIR" ]; then
    echo "Error: Destination directory $DEST_DIR does not exist."
    echo "Please run the install.sh script first."
    exit 1
fi
OWNER=$(stat -c '%U' "$DEST_DIR")
echo "Destination directory owner: $OWNER"

# --- Git Update & Sync ---
echo "=== Pulling latest changes and syncing files ==="
cd "$SCRIPT_DIR"
git pull
sudo -u "$OWNER" rsync -a --delete "$SCRIPT_DIR/" "$DEST_DIR/" --exclude ".git/" --exclude ".idea/" --exclude ".venv/"

# --- Dependencies ---
echo "=== Checking for new Python dependencies ==="
sudo -u "$OWNER" "$DEST_DIR/venv/bin/pip" install -r "$DEST_DIR/requirements.txt"

# --- Service Restart ---
echo "=== Restarting backend service ==="
sudo systemctl restart quiz

echo "=== Update finished ==="
echo "Application backend has been updated and restarted."
echo "A reboot is recommended to apply UI changes."
