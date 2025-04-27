#!/bin/bash
echo "          _   _                       ____   _____  "
echo "     /\\  | | | |                     / __ \\ / ____| "
echo "    /  \\ | |_| |__   ___ _ __   __ _| |  | | (___   "
echo "   / /\\ \\| __| '_ \\ / _ \\ '_ \\ / _\` | |  | |\\___ \\  "
echo "  / ____ \\ |_| | | |  __/ | | | (_| | |__| |____) | "
echo " /_/    \\_\\__|_| |_|\\___|_| |_|\\__,_|\\____/|_____/  "

# Check for root privileges
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root. Try using sudo."
  exit 1
fi

# Set hostname
echo "Setting hostname to AthenaOS..."
hostnamectl set-hostname AthenaOS

# Update /etc/hosts
echo "Updating /etc/hosts..."
sed -i '/127.0.1.1/d' /etc/hosts
echo "127.0.1.1   AthenaOS" >> /etc/hosts

# Update and upgrade the system
echo "Updating package lists..."
apt update

echo "Upgrading installed packages..."
apt upgrade -y

# Create user 'athenaos' with no password
if id "athenaos" &>/dev/null; then
  echo "User 'athenaos' already exists."
else
  echo "Creating user 'athenaos' with no password..."
  useradd -m -s /bin/bash athenaos
  passwd -d athenaos
  echo "User 'athenaos' has been created."
fi

# Install LXDE with no recommended packages
echo "Installing Desktop Enviroment (minimal)..."
apt install --no-install-recommends openbox sudo git -y
apt install xinit xserver-xorg x11-xserver-utils plymouth plymouth-themes -y 
apt install python3-venv python3-pip -y
apt install --no-install-recommends chromium feh

echo "Install Wi-Fi Tools..."
sudo apt -y install network-manager wpasupplicant firmware-linux-nonfree wireless-tools iw rfkill

# Enable autologin for athenaos
echo "Setting up autologin for 'athenaos'..."

mkdir -p /etc/systemd/system/getty@tty1.service.d

cat <<EOF > /etc/systemd/system/getty@tty1.service.d/override.conf
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin athenaos --noclear %I \$TERM
EOF

# Set LXDE to start automatically
echo "Setting Openbox to start for 'athenaos'..."
sudo -u athenaos bash -c 'echo "[[ -z \$DISPLAY && \$XDG_VTNR -eq 1 ]] && exec startx" >> ~/.bash_profile'
sudo -u athenaos bash -c 'echo "bash /home/athenaos/motd.sh" >> ~/.bashrc'

chown athenaos:athenaos /home/athenaos/.bash_profile

echo "Setting up Autoconfig"
mkdir /home/athenaos/.config/
mkdir /home/athenaos/.config/openbox/
chown -R athenaos:athenaos /home/athenaos/.config/
cp -rf startup.sh /home/athenaos/.config/openbox/autostart
chmod +x /home/athenaos/.config/openbox/autostart
chown -R athenaos:athenaos /home/athenaos/.config/openbox/autostart

cp -rf wallpaper.png /home/athenaos/wallpaper.png
chown -R athenaos:athenaos /home/athenaos/wallpaper.png

cp -rf athenaos.service /etc/systemd/system/athenaos.service
systemctl enable athenaos
cp -rf motd.sh /home/athenaos/motd.sh
chmod +x /home/athenaos/motd.sh
chown -R athenaos:athenaos /home/athenaos/motd.sh

cd /home/athenaos/ && git clone https://github.com/quietvw/AthenaOS_UI
cd /home/athenaos/AthenaOS_UI && pip3 install -r requirements.txt --break-system-packages
sudo -u athenaos bash -c 'cd /home/athenaos/AthenaOS_UI && pip3 install -r requirements.txt --break-system-packages'
chown -R athenaos:athenaos /home/athenaos/AthenaOS_UI
sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target

# Backup existing files
sudo cp /etc/os-release /etc/os-release.bak
sudo cp /etc/lsb-release /etc/lsb-release.bak || echo "No /etc/lsb-release found, skipping backup."
sudo cp /etc/default/grub /etc/default/grub.bak

# Update /etc/os-release
sudo tee /etc/os-release > /dev/null <<EOL
PRETTY_NAME="AthenaOS (Bravo)"
NAME="AthenaOS"
VERSION_ID="1.0"
VERSION="1.0 (Bravo)"
ID=athenaos
HOME_URL="https://www.adaclare.com"
SUPPORT_URL="https://www.adaclare.com"
BUG_REPORT_URL="https://www.adaclare.com"
EOL

# Update /etc/lsb-release
sudo tee /etc/lsb-release > /dev/null <<EOL
DISTRIB_ID=AthenaOS
DISTRIB_RELEASE=1.0
DISTRIB_CODENAME=bravo
DISTRIB_DESCRIPTION="AthenaOS 1.0 (Bravo)"
EOL

# Update GRUB menu
sudo sed -i 's/^GRUB_DISTRIBUTOR=.*/GRUB_DISTRIBUTOR="AthenaOS"/' /etc/default/grub || echo 'GRUB_DISTRIBUTOR="AthenaOS"' | sudo tee -a /etc/default/grub

# Update GRUB
sudo update-grub

echo "Starting AthenaOS login message setup..."

# Backup files
sudo cp /etc/issue /etc/issue.bak
sudo cp /etc/motd /etc/motd.bak
sudo cp /etc/issue.net /etc/issue.net.bak || echo "No /etc/issue.net found, skipping backup."

# AthenaOS ASCII Logo
ATHENA_ASCII="
                       AthenaOS - Bravo
"

# Write new /etc/issue
echo "$ATHENA_ASCII" | sudo tee /etc/issue > /dev/null
echo -e "\\n\\l" | sudo tee -a /etc/issue > /dev/null

# Write new /etc/motd
echo "$ATHENA_ASCII" | sudo tee /etc/motd > /dev/null

# Write new /etc/issue.net for SSH
echo "$ATHENA_ASCII" | sudo tee /etc/issue.net > /dev/null

# Disable dynamic motd scripts (optional)
if [ -d "/etc/update-motd.d/" ]; then
  echo "Disabling dynamic motd scripts..."
  sudo chmod -x /etc/update-motd.d/*
fi

#!/bin/bash

# AthenaOS Plymouth Theme Setup Script

set -e

THEME_NAME="athenaos_boot"
THEME_DIR="/usr/share/plymouth/themes/$THEME_NAME"

echo ">>> Installing AthenaOS Plymouth theme..."

# Copy theme (assuming the script and theme folder are in the same location)
sudo cp -r "$THEME_NAME" "$THEME_DIR"

# Set the new theme
echo ">>> Setting Plymouth theme to '$THEME_NAME'..."
sudo plymouth-set-default-theme -R "$THEME_NAME"

# Fix GRUB config to enable splash screen
echo ">>> Updating GRUB configuration..."

# Backup original GRUB config
sudo cp /etc/default/grub /etc/default/grub.bak

# Enable splash
sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=\"[^\"]*/& splash/' /etc/default/grub

# Optional: Reduce verbosity
sudo sed -i 's/quiet splash/quiet splash/' /etc/default/grub

# Update GRUB
if [ -f /boot/grub/grub.cfg ]; then
    echo ">>> Updating GRUB bootloader..."
    sudo update-grub
elif [ -f /boot/efi/EFI/*/grub.cfg ]; then
    echo ">>> Detected EFI system, updating GRUB bootloader..."
    sudo grub-mkconfig -o /boot/efi/EFI/*/grub.cfg
else
    echo ">>> Warning: GRUB config file not found, please update manually!"
fi

# Rebuild initramfs
sudo update-initramfs -u


echo "Setup complete. Hostname is now AthenaOS. Reboot to log in as 'athenaos' with LXDE."
reboot
