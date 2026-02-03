#!/data/data/com.termux/files/usr/bin/sh
LOG_FILE="$HOME/scripts/update.log"

# --- FUNCTIONS ---
log() {
    # Print to screen AND append to log file
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# --- CHECK NETWORK ---
if ping -c 1 google.com &>/dev/null; then
    log "Network available. Starting update..."
else
    log "No network detected. Exiting."
    exit 1
fi

# --- UPDATE PACKAGES ---
echo "Running apt update..."
apt update -y 2>&1

echo "Running pkg update..."
pkg update -y 2>&1

echo "Running pkg upgrade..."
pkg upgrade -y 2>&1 

echo "Instal pakges"
pkg install root-repo && pkg install x11-repo && pkg install tsu && pkg install iproute2 && pkg install termux-api && pkg install putty-tools && pkg install termux-tools  && pkg install openssh && pkg install termux-services && pkg install termux-api && pkg install git && pkg install wget -y 7>&1

echo "Storage Permissions"
am start -n com.miui.securitycenter/com.miui.permcenter.root.RootManagementActivity

setenforce 0
termux-setup-storage
chmod 777 storage

echo "All updates completed successfully!"
