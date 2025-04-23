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
apt install --no-install-recommends lxde -y
apt install xinit xserver-xorg -y 

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
sudo -u athenaos bash -c 'echo "startlxde" > ~/.xsession'
chown athenaos:athenaos /home/athenaos/.xsession
sudo -u athenaos bash -c 'echo "[[ -z \$DISPLAY && \$XDG_VTNR -eq 1 ]] && exec startlxde" >> ~/.bash_profile'
chown athenaos:athenaos /home/athenaos/.bash_profile
systemctl disable lightdm

echo "Setup complete. Hostname is now AthenaOS. Reboot to log in as 'athenaos' with LXDE."
