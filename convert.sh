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
echo "Installing LXDE (minimal)..."
apt install --no-install-recommends lxde sudo git -y
apt install xinit xserver-xorg plymouth -y 
apt install python3-venv python3-pip -y
sudo install -d -m 0755 /etc/apt/keyrings
wget -q https://packages.mozilla.org/apt/repo-signing-key.gpg -O- | sudo tee /etc/apt/keyrings/packages.mozilla.org.asc > /dev/null
echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" | sudo tee -a /etc/apt/sources.list.d/mozilla.list > /dev/null
echo '
Package: *
Pin: origin packages.mozilla.org
Pin-Priority: 1000
' | sudo tee /etc/apt/preferences.d/mozilla
sudo apt-get update && sudo apt-get install firefox -y

# Enable autologin for athenaos
echo "Setting up autologin for 'athenaos'..."

mkdir -p /etc/systemd/system/getty@tty1.service.d

cat <<EOF > /etc/systemd/system/getty@tty1.service.d/override.conf
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin athenaos --noclear %I \$TERM
EOF

# Set LXDE to start automatically
echo "Setting LXDE to start for 'athenaos'..."
sudo -u athenaos bash -c 'echo "[[ -z \$DISPLAY && \$XDG_VTNR -eq 1 ]] && exec startx" >> ~/.bash_profile'
sudo -u athenaos bash -c 'echo "bash /home/athenaos/motd.sh" >> ~/.bashrc'

chown athenaos:athenaos /home/athenaos/.bash_profile
systemctl disable lightdm

echo "Setting up Autoconfig"
mkdir /home/athenaos/.config/
mkdir /home/athenaos/.config/autostart/
echo "[Desktop Entry]
Type=Application
Name=AthenaOS
Exec=/home/athenaos/startup.sh" > /home/athenaos/.config/autostart/athenaos.desktop
chown -R athenaos:athenaos /home/athenaos/.config/
cp -rf startup.sh /home/athenaos/startup.sh
chmod +x /home/athenaos/startup.sh
chown -R athenaos:athenaos /home/athenaos/startup.sh

cp -rf wallpaper.png /home/athenaos/wallpaper.png
chown -R athenaos:athenaos /home/athenaos/wallpaper.png

cp -rf athenaos.service /etc/systemd/system/athenaos.service
systemctl enable athenaos
cp -rf motd.sh /home/athenaos/motd.sh
chmod +x /home/athenaos/motd.sh
chown -R athenaos:athenaos /home/athenaos/motd.sh

mv /usr/bin/lxpanel /usr/bin/lxpanel_no
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

echo "Setup complete. Hostname is now AthenaOS. Reboot to log in as 'athenaos' with LXDE."
reboot
